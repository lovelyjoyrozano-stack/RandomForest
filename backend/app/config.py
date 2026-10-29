"""Application settings, read once from environment variables / .env."""
import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent


def _bool(name: str, default: bool) -> bool:
    return os.getenv(name, str(default)).strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    database_url: str
    jwt_secret: str
    jwt_expire_minutes: int
    openweather_api_key: str | None
    default_city: str
    default_country: str
    cors_origins: tuple[str, ...]
    auto_create_tables: bool
    model_path: Path
    min_train_samples: int
    weather_cache_seconds: int
    email_host: str | None
    email_port: int
    email_username: str | None
    email_password: str | None
    email_from: str | None
    email_use_tls: bool
    password_reset_url: str
    password_reset_expire_minutes: int


@lru_cache
def get_settings() -> Settings:
    database_url = os.getenv("DATABASE_URL", "").strip()
    if not database_url:
        raise RuntimeError("DATABASE_URL is missing. Copy .env.example to .env and fill it in.")

    jwt_secret = os.getenv("JWT_SECRET", "").strip()
    if len(jwt_secret) < 32:
        raise RuntimeError(
            "JWT_SECRET must be set to a random string of at least 32 characters. "
            'Generate one with: python -c "import secrets; print(secrets.token_urlsafe(48))"'
        )

    origins = tuple(
        o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",") if o.strip()
    )

    return Settings(
        database_url=database_url,
        jwt_secret=jwt_secret,
        jwt_expire_minutes=int(os.getenv("JWT_EXPIRE_MINUTES", "720")),
        openweather_api_key=os.getenv("OPENWEATHER_API_KEY") or None,
        default_city=os.getenv("DEFAULT_CITY", "Cabadbaran"),
        default_country=os.getenv("DEFAULT_COUNTRY", "PH"),
        cors_origins=origins or ("*",),
        auto_create_tables=_bool("AUTO_CREATE_TABLES", True),
        model_path=Path(os.getenv("MODEL_PATH", BASE_DIR / "models" / "yield_rf.joblib")),
        min_train_samples=int(os.getenv("MIN_TRAIN_SAMPLES", "10")),
        weather_cache_seconds=int(os.getenv("WEATHER_CACHE_SECONDS", "600")),
        email_host=os.getenv("EMAIL_HOST") or None,
        email_port=int(os.getenv("EMAIL_PORT", "587")),
        email_username=os.getenv("EMAIL_USERNAME") or None,
        email_password=os.getenv("EMAIL_PASSWORD") or None,
        email_from=os.getenv("EMAIL_FROM") or os.getenv("EMAIL_USERNAME") or None,
        email_use_tls=_bool("EMAIL_USE_TLS", True),
        password_reset_url=os.getenv("PASSWORD_RESET_URL", "http://localhost:5000/reset-password"),
        password_reset_expire_minutes=int(os.getenv("PASSWORD_RESET_EXPIRE_MINUTES", "30")),
    )
