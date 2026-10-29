"""Random Forest yield model: build data, train, persist, predict.

Target:   harvested sacks per hectare.
Features: mean temperature, mean daily rainfall and mean humidity recorded for
          the farm during the 120 days before the harvest date.

Real training data comes from the app's own records (productivity_records joined
with the climate_readings the farmer has saved). A synthetic generator is
provided ONLY so the feature can be demonstrated before enough real records
exist; models trained from it are flagged `synthetic_demo` everywhere.
"""
from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from pathlib import Path
from threading import Lock

import joblib
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import KFold, cross_val_predict
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..models import ClimateReading, Farm, ProductivityRecord

log = logging.getLogger(__name__)

FEATURES = ["avg_temperature", "avg_rainfall_mm", "avg_humidity"]
SEASON_DAYS = 120
MIN_READINGS_PER_RECORD = 3
SOURCE_REAL = "real"
SOURCE_SYNTHETIC = "synthetic_demo"


class ModelError(Exception):
    def __init__(self, detail: str, status_code: int = 409):
        super().__init__(detail)
        self.detail = detail
        self.status_code = status_code


# ------------------------------------------------------------------- data
def climate_features(
    db: Session, farm_id: int, start: datetime, end: datetime
) -> tuple[list[float], int] | None:
    """Mean climate for a farm in [start, end]; None if too few readings."""
    row = db.execute(
        select(
            func.avg(ClimateReading.temperature),
            func.avg(ClimateReading.rainfall),
            func.avg(ClimateReading.humidity),
            func.count(ClimateReading.reading_id),
        ).where(
            ClimateReading.farm_id == farm_id,
            ClimateReading.created_at >= start,
            ClimateReading.created_at <= end,
        )
    ).one()
    if not row[3] or row[3] < MIN_READINGS_PER_RECORD:
        return None
    return [float(row[0]), float(row[1]), float(row[2])], int(row[3])


def build_training_data(db: Session) -> tuple[np.ndarray, np.ndarray]:
    rows = db.execute(
        select(ProductivityRecord, Farm.area_hectares)
        .join(Farm, Farm.farm_id == ProductivityRecord.farm_id)
        .where(Farm.area_hectares.is_not(None), Farm.area_hectares > 0)
    ).all()

    X, y = [], []
    for record, area in rows:
        end = datetime.combine(record.harvest_date, datetime.max.time())
        start = end - timedelta(days=SEASON_DAYS)
        feats = climate_features(db, record.farm_id, start, end)
        if feats is None:
            continue
        X.append(feats[0])
        y.append(record.harvested_sacks / area)
    return np.array(X, dtype=float).reshape(-1, len(FEATURES)), np.array(y, dtype=float)


def synthetic_dataset(n: int = 500, seed: int = 42) -> tuple[np.ndarray, np.ndarray]:
    """Plausible-looking but INVENTED data for demos. Never use for decisions."""
    rng = np.random.default_rng(seed)
    temp = rng.normal(27.5, 2.0, n)
    rain = rng.gamma(2.0, 4.0, n)
    hum = np.clip(rng.normal(80, 6, n), 40, 100)
    per_ha = (
        85
        - 1.8 * (temp - 27) ** 2
        - 0.06 * (rain - 9) ** 2
        + 0.2 * (hum - 80)
        + rng.normal(0, 4, n)
    )
    return np.column_stack([temp, rain, hum]), np.clip(per_ha, 10, None)


# ---------------------------------------------------------------- training
def train(X: np.ndarray, y: np.ndarray, source: str, min_samples: int = 10) -> dict:
    n = len(y)
    if n < min_samples:
        raise ModelError(
            f"Not enough data to train: {n} usable harvest record(s), need at least {min_samples}. "
            "A record is usable when its farm has an area set and at least "
            f"{MIN_READINGS_PER_RECORD} saved climate readings in the 120 days before harvest."
        )

    def make():
        return RandomForestRegressor(
            n_estimators=300, min_samples_leaf=2, max_features=1.0,
            oob_score=True, bootstrap=True, random_state=42, n_jobs=-1,
        )

    folds = min(5, n)
    cv_pred = cross_val_predict(make(), X, y, cv=KFold(folds, shuffle=True, random_state=42))
    model = make().fit(X, y)

    return {
        "model": model,
        "features": FEATURES,
        "source": source,
        "n_samples": int(n),
        "trained_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "metrics": {
            "cv_folds": folds,
            "cv_mae_sacks_per_ha": round(float(mean_absolute_error(y, cv_pred)), 3),
            "cv_r2": round(float(r2_score(y, cv_pred)), 3),
            "oob_r2": round(float(model.oob_score_), 3),
        },
        "feature_importance": {
            f: round(float(v), 4) for f, v in zip(FEATURES, model.feature_importances_)
        },
        "target_range": [round(float(y.min()), 2), round(float(y.max()), 2)],
    }


def save(bundle: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    joblib.dump(bundle, tmp)
    tmp.replace(path)
    _cache.clear()


# ------------------------------------------------------------- loading/use
_cache: dict[str, tuple[float, dict]] = {}
_cache_lock = Lock()


def load(path: Path) -> dict:
    """Load the persisted bundle (reloaded automatically when the file changes).
    Only ever load files this application wrote itself: joblib uses pickle."""
    if not path.exists():
        raise ModelError(
            "No yield model has been trained yet. An administrator can train one "
            "(POST /predictions/train) or run `python train_model.py`.",
            status_code=503,
        )
    mtime = path.stat().st_mtime
    with _cache_lock:
        hit = _cache.get(str(path))
        if hit and hit[0] == mtime:
            return hit[1]
        bundle = joblib.load(path)
        _cache[str(path)] = (mtime, bundle)
        return bundle


def public_info(bundle: dict) -> dict:
    info = {k: bundle[k] for k in ("source", "n_samples", "trained_at", "metrics",
                                   "feature_importance", "features", "target_range")}
    info["model_type"] = "RandomForestRegressor"
    if bundle["source"] != SOURCE_REAL:
        info["warning"] = (
            "This model was trained on SYNTHETIC demo data, not real harvests. "
            "Do not use its numbers for real decisions."
        )
    return info


def predict(bundle: dict, climate: list[float]) -> dict:
    model: RandomForestRegressor = bundle["model"]
    x = np.array([climate], dtype=float)
    per_tree = np.array([t.predict(x)[0] for t in model.estimators_])
    return {
        "sacks_per_hectare": round(float(per_tree.mean()), 2),
        "range_low": round(float(np.percentile(per_tree, 10)), 2),
        "range_high": round(float(np.percentile(per_tree, 90)), 2),
    }
