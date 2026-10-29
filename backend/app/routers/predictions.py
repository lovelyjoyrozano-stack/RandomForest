from datetime import timedelta
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..config import get_settings
from ..database import get_db
from ..deps import get_owned_farm
from ..models import User, utcnow
from ..security import get_current_user, require_admin
from ..services import ml

router = APIRouter(prefix="/predictions", tags=["Yield prediction (Random Forest)"])

RECENT_DAYS = 30


@router.get("/model")
def model_info(_: User = Depends(get_current_user)):
    return ml.public_info(ml.load(get_settings().model_path))


class TrainIn(BaseModel):
    source: Literal["real", "synthetic"] = "real"


@router.post("/train")
def train_model(body: TrainIn, db: Session = Depends(get_db), _: User = Depends(require_admin)):
    settings = get_settings()
    if body.source == "synthetic":
        X, y = ml.synthetic_dataset()
        bundle = ml.train(X, y, ml.SOURCE_SYNTHETIC, min_samples=1)
    else:
        X, y = ml.build_training_data(db)
        bundle = ml.train(X, y, ml.SOURCE_REAL, settings.min_train_samples)
    ml.save(bundle, settings.model_path)
    return {"message": "Model trained and saved.", "model": ml.public_info(bundle)}


@router.get("/yield")
def predict_yield(
    farm_id: int = Query(..., gt=0),
    temperature: float | None = Query(None, ge=-20, le=60, description="Override mean temperature, deg C"),
    rainfall: float | None = Query(None, ge=0, le=500, description="Override mean daily rainfall, mm"),
    humidity: float | None = Query(None, ge=0, le=100, description="Override mean humidity, %"),
    price_per_sack: float | None = Query(None, ge=0),
    production_cost: float | None = Query(None, ge=0),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    farm = get_owned_farm(farm_id, db, user)
    if not farm.area_hectares:
        raise HTTPException(status_code=400, detail="Set this farm's area (hectares) to get a yield prediction.")

    bundle = ml.load(get_settings().model_path)

    overrides = {"temperature": temperature, "rainfall": rainfall, "humidity": humidity}
    given = {k: v for k, v in overrides.items() if v is not None}
    if len(given) == 3:
        climate, basis, n_readings = [temperature, rainfall, humidity], "manual", 0
    else:
        now = utcnow()
        recent = ml.climate_features(db, farm.farm_id, now - timedelta(days=RECENT_DAYS), now)
        if recent is None:
            raise HTTPException(
                status_code=409,
                detail=f"Need at least {ml.MIN_READINGS_PER_RECORD} saved climate readings from the last "
                       f"{RECENT_DAYS} days. Open Climate Monitoring a few times first, or supply "
                       "temperature, rainfall and humidity manually.",
            )
        climate, n_readings = recent
        basis = "recent_readings"
        for i, key in enumerate(("temperature", "rainfall", "humidity")):
            if overrides[key] is not None:
                climate[i] = overrides[key]
                basis = "mixed"

    p = ml.predict(bundle, climate)
    area = farm.area_hectares
    total = round(p["sacks_per_hectare"] * area, 1)

    result = {
        "farm_id": farm.farm_id,
        "area_hectares": area,
        "climate_basis": basis,
        "readings_used": n_readings,
        "climate_inputs": dict(zip(ml.FEATURES, [round(c, 2) for c in climate])),
        "predicted_sacks_per_hectare": p["sacks_per_hectare"],
        "predicted_total_sacks": total,
        "range_total_sacks": [round(p["range_low"] * area, 1), round(p["range_high"] * area, 1)],
        "range_note": "10th-90th percentile of the individual trees in the forest; not a guarantee.",
        "model": ml.public_info(bundle),
    }
    if price_per_sack is not None and production_cost is not None:
        result["projected_profit_if_all_sold"] = round(total * price_per_sack - production_cost, 2)
    return result
