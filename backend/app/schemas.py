"""Request/response models."""
from datetime import date, datetime
import re

from pydantic import BaseModel, ConfigDict, Field, field_validator

from .security import MAX_PASSWORD_BYTES


# -------------------------------------------------------------------- auth
class RegisterIn(BaseModel):
    full_name: str = Field(min_length=2, max_length=150)
    username: str = Field(min_length=3, max_length=50)
    email: str = Field(min_length=5, max_length=254)
    password: str = Field(min_length=8, max_length=72)

    @field_validator("full_name", "username")
    @classmethod
    def _strip(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("must not be blank")
        return v

    @field_validator("username")
    @classmethod
    def _no_spaces(cls, v: str) -> str:
        if any(ch.isspace() for ch in v):
            raise ValueError("must not contain spaces")
        return v

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        v = v.strip().lower()
        if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", v):
            raise ValueError("enter a valid email address")
        return v

    @field_validator("password")
    @classmethod
    def _strong_password(cls, v: str) -> str:
        if len(v.encode("utf-8")) > MAX_PASSWORD_BYTES:
            raise ValueError(f"must be at most {MAX_PASSWORD_BYTES} bytes")
        if len(v) < 8 or not re.search(r"[A-Z]", v) or not re.search(r"[a-z]", v) or not re.search(r"[0-9]", v) or not re.search(r"[^A-Za-z0-9]", v):
            raise ValueError("Password must be at least 8 characters and include uppercase, lowercase, number, and special character.")
        return v


class ForgotPasswordIn(BaseModel):
    email: str = Field(min_length=5, max_length=254)

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        v = v.strip().lower()
        if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", v):
            raise ValueError("enter a valid email address")
        return v


class ResetPasswordIn(BaseModel):
    token: str = Field(min_length=32, max_length=256)
    password: str = Field(min_length=8, max_length=72)

    @field_validator("password")
    @classmethod
    def _strong_password(cls, v: str) -> str:
        if len(v.encode("utf-8")) > MAX_PASSWORD_BYTES or len(v) < 8 or not re.search(r"[A-Z]", v) or not re.search(r"[a-z]", v) or not re.search(r"[0-9]", v) or not re.search(r"[^A-Za-z0-9]", v):
            raise ValueError("Password must be at least 8 characters and include uppercase, lowercase, number, and special character.")
        return v


class LoginIn(BaseModel):
    username: str = Field(min_length=1, max_length=50)
    password: str = Field(min_length=1, max_length=200)
    role: str | None = None  # accepted for backward compatibility, not trusted


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    user_id: int
    full_name: str
    username: str
    role: str
    email: str | None = None


class TokenOut(BaseModel):
    message: str
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserOut


# ------------------------------------------------------------------- farms
class FarmCreate(BaseModel):
    farm_code: str | None = Field(default=None, min_length=1, max_length=50)
    farm_name: str = Field(min_length=1, max_length=150)
    location: str = Field(min_length=1, max_length=255)
    area_hectares: float | None = Field(default=None, gt=0, le=100000)
    city: str | None = Field(default=None, min_length=1, max_length=100)

    @field_validator("farm_code", "farm_name", "location", "city")
    @classmethod
    def _strip(cls, v):
        return v.strip() if isinstance(v, str) else v


class FarmUpdate(BaseModel):
    farm_name: str | None = Field(default=None, min_length=1, max_length=150)
    location: str | None = Field(default=None, min_length=1, max_length=255)
    area_hectares: float | None = Field(default=None, gt=0, le=100000)
    city: str | None = Field(default=None, min_length=1, max_length=100)
    status: str | None = Field(default=None, pattern="^(Active|Inactive)$")


class FarmOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    farm_id: int
    farm_code: str
    farm_name: str
    location: str
    status: str
    area_hectares: float | None = None
    city: str | None = None
    latitude: float | None = None
    longitude: float | None = None

# ----------------------------------------------------------------- climate
class ClimateInput(BaseModel):
    farm_id: int = Field(gt=0)
    temperature: float = Field(ge=-20, le=60)
    rainfall: float = Field(ge=0, le=2000)
    humidity: float = Field(ge=0, le=100)
    weather_condition: str = Field(default="Unknown", max_length=100)
    rain_probability: float = Field(default=0, ge=0, le=100)


# ------------------------------------------------------------ productivity
class ProductivityInput(BaseModel):
    farm_id: int = Field(gt=0)
    crop_name: str = Field(min_length=1, max_length=100)
    harvested_sacks: int = Field(ge=0, le=10_000_000)
    sold_sacks: int = Field(ge=0, le=10_000_000)
    price_per_sack: float = Field(ge=0, le=1_000_000)
    production_cost: float = Field(ge=0, le=1_000_000_000)
    harvest_date: date

    @field_validator("crop_name")
    @classmethod
    def _strip(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("must not be blank")
        return v

    @field_validator("harvest_date")
    @classmethod
    def _not_future(cls, v: date) -> date:
        if v > date.today():
            raise ValueError("harvest date cannot be in the future")
        return v
