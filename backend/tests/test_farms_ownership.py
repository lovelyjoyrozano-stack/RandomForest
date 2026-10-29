from conftest import register_and_login


def test_create_and_list_own_farms_only(client, auth, farm):
    other = register_and_login(client, username="maria", name="Maria Santos")
    client.post("/farms", json={"farm_name": "Hers", "location": "Butuan"}, headers=other)

    mine = client.get("/farms", headers=auth).json()
    assert [f["farm_name"] for f in mine] == ["Riverside"]
    assert farm["farm_code"].startswith("FARM-")


def test_cannot_touch_another_farmers_farm(client, auth, farm):
    other = register_and_login(client, username="maria", name="Maria Santos")
    fid = farm["farm_id"]
    assert client.get(f"/farms/{fid}", headers=other).status_code == 404
    assert client.patch(f"/farms/{fid}", json={"farm_name": "Hijacked"}, headers=other).status_code == 404
    assert client.get("/productivity/records", params={"farm_id": fid}, headers=other).status_code == 404
    body = {"farm_id": fid, "crop_name": "Rice", "harvested_sacks": 10, "sold_sacks": 5,
            "price_per_sack": 1000, "production_cost": 100, "harvest_date": "2026-01-01"}
    assert client.post("/productivity/evaluate", json=body, headers=other).status_code == 404


def test_duplicate_farm_code(client, auth):
    body = {"farm_code": "A-1", "farm_name": "One", "location": "X"}
    assert client.post("/farms", json=body, headers=auth).status_code == 201
    assert client.post("/farms", json=body, headers=auth).status_code == 409


def test_update_farm(client, auth, farm):
    r = client.patch(f"/farms/{farm['farm_id']}", json={"area_hectares": 3.5}, headers=auth)
    assert r.status_code == 200 and r.json()["area_hectares"] == 3.5
