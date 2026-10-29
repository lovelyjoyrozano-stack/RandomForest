BODY = {"crop_name": "  Rice ", "harvested_sacks": 100, "sold_sacks": 80,
        "price_per_sack": 1200, "production_cost": 50000, "harvest_date": "2026-03-01"}


def test_evaluate_profit_and_flat_fields(client, auth, farm):
    r = client.post("/productivity/evaluate", json={**BODY, "farm_id": farm["farm_id"]}, headers=auth)
    assert r.status_code == 200, r.text
    d = r.json()
    # The mobile app reads these top-level fields.
    assert d["crop_name"] == "Rice"
    assert d["total_sales"] == 96000 and d["estimated_profit"] == 46000
    assert d["performance_status"] == "GOOD" and d["performance_message"]
    assert d["yield_sacks_per_ha"] == 50.0  # 100 sacks / 2 ha
    assert d["record"]["record_id"] == d["record_id"]


def test_loss_and_break_even(client, auth, farm):
    fid = farm["farm_id"]
    loss = client.post("/productivity/evaluate", headers=auth,
                       json={**BODY, "farm_id": fid, "production_cost": 200000}).json()
    even = client.post("/productivity/evaluate", headers=auth,
                       json={**BODY, "farm_id": fid, "production_cost": 96000}).json()
    assert loss["performance_status"] == "NOT GOOD" and even["performance_status"] == "BREAK EVEN"


def test_validation(client, auth, farm):
    fid = farm["farm_id"]
    over = client.post("/productivity/evaluate", headers=auth, json={**BODY, "farm_id": fid, "sold_sacks": 101})
    assert over.status_code == 400
    future = client.post("/productivity/evaluate", headers=auth, json={**BODY, "farm_id": fid, "harvest_date": "2999-01-01"})
    assert future.status_code == 422


def test_records_summary_delete(client, auth, farm):
    fid = farm["farm_id"]
    client.post("/productivity/evaluate", headers=auth, json={**BODY, "farm_id": fid})
    client.post("/productivity/evaluate", headers=auth, json={**BODY, "farm_id": fid, "crop_name": "Corn",
                                                              "production_cost": 100000, "harvest_date": "2026-06-01"})
    recs = client.get("/productivity/records", params={"farm_id": fid}, headers=auth).json()
    assert recs["total_records"] == 2 and recs["records"][0]["crop_name"] == "Corn"  # newest first

    s = client.get("/productivity/summary", params={"farm_id": fid}, headers=auth).json()
    assert s["total_profit"] == 46000 + (96000 - 100000)
    assert s["profitable_harvests"] == 1 and len(s["by_crop"]) == 2

    rid = recs["records"][0]["record_id"]
    assert client.delete(f"/productivity/records/{rid}", headers=auth).status_code == 200
    assert client.get("/productivity/records", params={"farm_id": fid}, headers=auth).json()["total_records"] == 1
