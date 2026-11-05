from app.services import advisor
from conftest import forecast_payload


def test_advisor_rules():
    assert advisor.assess_planting(28, 0, 10)[0] == "SUITABLE"
    assert advisor.assess_planting(28, 25, 10)[0] == "CAUTION"
    assert advisor.assess_planting(36, 0, 10)[0] == "CAUTION"
    assert advisor.assess_planting(39, 0, 10)[0] == "NOT SUITABLE"
    assert advisor.assess_planting(28, 60, 10)[0] == "NOT SUITABLE"
    assert advisor.assess_planting(28, 0, 85)[0] == "NOT SUITABLE"
    assert advisor.assess_planting(28, 0, 10, has_thunderstorm=True)[0] == "CAUTION"


def test_planting_advice_saves_once_then_dedupes(client, auth, farm, mock_weather):
    p = {"farm_id": farm["farm_id"]}
    first = client.get("/climate/planting-advice", params=p, headers=auth).json()
    assert first["planting_status"] == "SUITABLE" and first["saved"] is True
    assert len(first["forecasts"]) == 8

    second = client.get("/climate/planting-advice", params=p, headers=auth).json()
    assert second["saved"] is False and second["reading_id"] == first["reading_id"]

    hist = client.get("/climate/history", params=p, headers=auth).json()
    assert len(hist["readings"]) == 1 and hist["readings"][0]["planting_status"] == "SUITABLE"


def test_thunderstorm_and_heavy_rain(client, auth, farm, mock_weather):
    mock_weather["payload"] = forecast_payload(main="Thunderstorm", desc="thunderstorm")
    r = client.get("/climate/planting-advice", params={"farm_id": farm["farm_id"]}, headers=auth).json()
    assert r["planting_status"] == "CAUTION"


def test_weather_service_errors_surface_cleanly(client, auth, farm, monkeypatch):
    from app.services import weather

    def boom(city):
        raise weather.WeatherError("Could not connect to the weather service.")
    monkeypatch.setattr(weather, "fetch_forecast", boom)
    r = client.get("/climate/planting-advice", params={"farm_id": farm["farm_id"]}, headers=auth)
    assert r.status_code == 502 and "weather" in r.json()["detail"].lower()


def test_manual_assessment(client, auth, farm):
    r = client.post("/climate/assess", headers=auth, json={
        "farm_id": farm["farm_id"], "temperature": 29, "rainfall": 55, "humidity": 90})
    assert r.status_code == 200 and r.json()["planting_status"] == "NOT SUITABLE"
    bad = client.post("/climate/assess", headers=auth, json={
        "farm_id": farm["farm_id"], "temperature": 29, "rainfall": 5, "humidity": 140})
    assert bad.status_code == 422


def test_advice_uses_current_weather(client, auth, farm, mock_weather, monkeypatch):
    from app.services import weather

    monkeypatch.setattr(weather, "get_current_weather", lambda city: {
        "city": city, "weather_main": "Clear", "weather_condition": "clear sky",
        "temperature_celsius": 39.5, "humidity_percent": 60,
        "rainfall_mm": 0, "wind_speed_ms": 1.0, "observed_at": 0,
    })
    r = client.get("/climate/planting-advice", params={"farm_id": farm["farm_id"]}, headers=auth).json()
    assert r["current_temperature_c"] == 39.5
    assert r["planting_status"] == "NOT SUITABLE"
    assert r["based_on"] == "current weather"


def test_advice_falls_back_when_current_weather_fails(client, auth, farm, mock_weather, monkeypatch):
    from app.services import weather

    def boom(city):
        raise weather.WeatherError("down")
    monkeypatch.setattr(weather, "get_current_weather", boom)
    r = client.get("/climate/planting-advice", params={"farm_id": farm["farm_id"]}, headers=auth)
    assert r.status_code == 200 and r.json()["planting_status"] == "SUITABLE"