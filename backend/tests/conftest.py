import os
import sys
from datetime import timedelta
from pathlib import Path

import pytest

# Must be set before the app is imported.
os.environ["DATABASE_URL"] = "sqlite://"
os.environ["JWT_SECRET"] = "test-secret-" + "x" * 40
os.environ["OPENWEATHER_API_KEY"] = "test-key"
os.environ["MODEL_PATH"] = str(Path(__file__).parent / "_tmp_model.joblib")
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from fastapi.testclient import TestClient  # noqa: E402

from app.database import Base, SessionLocal, engine, init_db  # noqa: E402
from app.main import app  # noqa: E402
from app.security import login_throttle  # noqa: E402
from app.services import weather  # noqa: E402


def forecast_payload(temp=28.0, rain=0.0, pop=0.1, main="Clouds", desc="scattered clouds"):
    item = {
        "dt_txt": "2026-10-21 12:00:00",
        "main": {"temp": temp, "humidity": 80},
        "weather": [{"main": main, "description": desc}],
        "pop": pop,
        "rain": {"3h": rain} if rain else {},
    }
    return {"city": {"name": "Cabadbaran"}, "list": [dict(item) for _ in range(10)]}


@pytest.fixture(autouse=True)
def fresh_db():
    Base.metadata.drop_all(engine)
    init_db()
    login_throttle._failures.clear()
    weather.clear_cache()
    model = Path(os.environ["MODEL_PATH"])
    model.unlink(missing_ok=True)
    yield
    model.unlink(missing_ok=True)


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


@pytest.fixture
def db():
    with SessionLocal() as session:
        yield session


@pytest.fixture
def mock_weather(monkeypatch):
    state = {"payload": forecast_payload()}
    monkeypatch.setattr(weather, "fetch_forecast", lambda city: state["payload"])
    return state


def register_and_login(client, username="juan", password="Secret123!", name="Juan Dela Cruz"):
    r = client.post("/register", json={"full_name": name, "username": username, "email": f"{username}@example.com", "password": password})
    assert r.status_code == 201, r.text
    r = client.post("/login", json={"username": username, "password": password})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def auth(client):
    return register_and_login(client)


@pytest.fixture
def farm(client, auth):
    r = client.post("/farms", json={"farm_name": "Riverside", "location": "Cabadbaran", "area_hectares": 2.0}, headers=auth)
    assert r.status_code == 201, r.text
    return r.json()["farm"]
