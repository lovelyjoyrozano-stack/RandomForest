from sqlalchemy import select

from app.models import User
from app.security import hash_password
from conftest import register_and_login


def test_register_login_me(client):
    headers = register_and_login(client)
    me = client.get("/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["username"] == "juan" and me.json()["role"] == "Farmer"
    assert "password" not in me.json()


def test_password_is_hashed(client, db):
    register_and_login(client)
    stored = db.scalar(select(User.password))
    assert stored.startswith("$2") and "Secret123!" not in stored


def test_duplicate_username_case_insensitive(client):
    register_and_login(client, username="Juan")
    r = client.post("/register", json={"full_name": "Other Person", "username": "juan", "email": "other@example.com", "password": "Secret123!"})
    assert r.status_code == 409


def test_validation_errors_are_readable(client):
    r = client.post("/register", json={"full_name": "A", "username": "x y", "email": "a@example.com", "password": "short"})
    assert r.status_code == 422
    assert isinstance(r.json()["detail"], str)


def test_password_over_72_bytes_rejected(client):
    r = client.post("/register", json={"full_name": "Long Pass", "username": "longpass", "email": "long@example.com", "password": "Aé" * 40})
    assert r.status_code == 422


def test_wrong_password_and_unknown_user_look_identical(client):
    register_and_login(client)
    a = client.post("/login", json={"username": "juan", "password": "wrong-password"})
    b = client.post("/login", json={"username": "nobody", "password": "wrong-password"})
    assert a.status_code == b.status_code == 401
    assert a.json() == b.json()


def test_login_lockout_after_repeated_failures(client):
    register_and_login(client)
    for _ in range(5):
        assert client.post("/login", json={"username": "juan", "password": "bad-password"}).status_code == 401
    assert client.post("/login", json={"username": "juan", "password": "Secret123!"}).status_code == 429


def test_protected_routes_need_token(client):
    assert client.get("/farms").status_code == 401
    assert client.get("/farms", headers={"Authorization": "Bearer garbage"}).status_code == 401


def test_legacy_passlib_bcrypt_hash_still_verifies(client, db):
    # Accounts created by the original app used passlib's $2b$ bcrypt hashes.
    db.add(User(full_name="Old User", username="olduser", password=hash_password("legacy-pass-1"), role="Farmer"))
    db.commit()
    r = client.post("/login", json={"username": "olduser", "password": "legacy-pass-1", "role": "Farmer"})
    assert r.status_code == 200
