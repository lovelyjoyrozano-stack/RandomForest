from datetime import timedelta

import numpy as np
import pytest

from app.models import ClimateReading, Farm, ProductivityRecord, User, utcnow
from app.security import hash_password
from app.services import ml
from conftest import register_and_login


def make_admin(client, db):
    db.add(User(full_name="Admin", username="admin", password=hash_password("admin-pass-1"), role="Admin"))
    db.commit()
    r = client.post("/login", json={"username": "admin", "password": "admin-pass-1"})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def add_readings(db, farm_id, n=5, days_ago=2, temp=27.0, rain=8.0, hum=80.0):
    for i in range(n):
        db.add(ClimateReading(farm_id=farm_id, temperature=temp, rainfall=rain, humidity=hum,
                              created_at=utcnow() - timedelta(days=days_ago, hours=i)))
    db.commit()


def test_synthetic_model_is_learnable_and_flagged():
    X, y = ml.synthetic_dataset(400)
    bundle = ml.train(X, y, ml.SOURCE_SYNTHETIC, min_samples=1)
    assert bundle["metrics"]["cv_r2"] > 0.6
    assert "warning" in ml.public_info(bundle)
    # Optimal conditions beat hot/dry-stress conditions.
    good = ml.predict(bundle, [27, 9, 80])["sacks_per_hectare"]
    bad = ml.predict(bundle, [34, 30, 60])["sacks_per_hectare"]
    assert good > bad


def test_train_refuses_tiny_datasets():
    with pytest.raises(ml.ModelError):
        ml.train(np.ones((3, 3)), np.ones(3), ml.SOURCE_REAL, min_samples=10)


def test_predict_requires_model_then_works(client, auth, farm, db):
    add_readings(db, farm["farm_id"])
    r = client.get("/predictions/yield", params={"farm_id": farm["farm_id"]}, headers=auth)
    assert r.status_code == 503  # no model trained yet

    admin = make_admin(client, db)
    t = client.post("/predictions/train", json={"source": "synthetic"}, headers=admin)
    assert t.status_code == 200 and t.json()["model"]["source"] == "synthetic_demo"

    r = client.get("/predictions/yield", params={"farm_id": farm["farm_id"], "price_per_sack": 1200,
                                                 "production_cost": 40000}, headers=auth)
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["climate_basis"] == "recent_readings" and d["readings_used"] == 5
    lo, hi = d["range_total_sacks"]
    assert lo <= d["predicted_total_sacks"] <= hi
    assert d["predicted_total_sacks"] == pytest.approx(d["predicted_sacks_per_hectare"] * 2.0, abs=0.1)
    assert "SYNTHETIC" in d["model"]["warning"]
    assert "projected_profit_if_all_sold" in d


def test_predict_what_if_and_missing_data(client, auth, farm, db):
    admin = make_admin(client, db)
    client.post("/predictions/train", json={"source": "synthetic"}, headers=admin)

    no_data = client.get("/predictions/yield", params={"farm_id": farm["farm_id"]}, headers=auth)
    assert no_data.status_code == 409

    manual = client.get("/predictions/yield", headers=auth, params={
        "farm_id": farm["farm_id"], "temperature": 27, "rainfall": 9, "humidity": 80})
    assert manual.status_code == 200 and manual.json()["climate_basis"] == "manual"


def test_predict_needs_farm_area(client, auth, db):
    f = client.post("/farms", json={"farm_name": "NoArea", "location": "X"}, headers=auth).json()["farm"]
    assert client.get("/predictions/yield", params={"farm_id": f["farm_id"]}, headers=auth).status_code == 400


def test_train_endpoint_is_admin_only(client, auth):
    assert client.post("/predictions/train", json={"source": "synthetic"}, headers=auth).status_code == 403


def test_real_training_from_database_records(client, auth, farm, db):
    fid = farm["farm_id"]  # 2 ha
    rng = np.random.default_rng(1)
    for i in range(14):
        harvest = utcnow().date() - timedelta(days=400 - i * 20)
        temp = 25 + i * 0.4
        for h in range(4):  # readings inside the 120-day pre-harvest window
            db.add(ClimateReading(farm_id=fid, temperature=temp, rainfall=8, humidity=80,
                                  created_at=utcnow() - timedelta(days=400 - i * 20 + 10 + h)))
        per_ha = 90 - 2 * (temp - 27) ** 2 + rng.normal(0, 1)
        db.add(ProductivityRecord(farm_id=fid, crop_name="Rice", harvested_sacks=int(per_ha * 2),
                                  sold_sacks=10, price_per_sack=1000, production_cost=1000, harvest_date=harvest))
    db.commit()

    X, y = ml.build_training_data(db)
    assert len(y) == 14 and X.shape == (14, 3)

    admin = make_admin(client, db)
    r = client.post("/predictions/train", json={"source": "real"}, headers=admin)
    assert r.status_code == 200, r.text
    info = r.json()["model"]
    assert info["source"] == "real" and "warning" not in info and info["n_samples"] == 14
