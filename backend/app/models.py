"""ORM models. Table/column names match the original project's database."""
from datetime import date, datetime, timezone

from sqlalchemy import (
    Date, DateTime, Float, ForeignKey, Index, Integer, Numeric, String, Text, Boolean,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class User(Base):
    __tablename__ = "users"

    user_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    full_name: Mapped[str] = mapped_column(String(150))
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    email: Mapped[str | None] = mapped_column(String(254), unique=True, index=True, nullable=True)
    password: Mapped[str] = mapped_column(String(255))  # bcrypt hash
    role: Mapped[str] = mapped_column(String(20), default="Farmer")
    created_at: Mapped[datetime | None] = mapped_column(DateTime, default=utcnow)

    farms: Mapped[list["Farm"]] = relationship(back_populates="farmer")


class Farm(Base):
    __tablename__ = "farms"

    farm_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    farmer_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), index=True)
    farm_code: Mapped[str] = mapped_column(String(50), unique=True)
    farm_name: Mapped[str] = mapped_column(String(150))
    location: Mapped[str] = mapped_column(String(255))
    status: Mapped[str] = mapped_column(String(20), default="Active")
    area_hectares: Mapped[float | None] = mapped_column(Float, nullable=True)
    city: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime | None] = mapped_column(DateTime, default=utcnow)

    farmer: Mapped[User] = relationship(back_populates="farms")


class ClimateReading(Base):
    __tablename__ = "climate_readings"

    reading_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    farm_id: Mapped[int] = mapped_column(ForeignKey("farms.farm_id"), index=True)
    temperature: Mapped[float] = mapped_column(Float)
    rainfall: Mapped[float] = mapped_column(Float, default=0)
    humidity: Mapped[float] = mapped_column(Float)
    weather_condition: Mapped[str | None] = mapped_column(String(100), default="Unknown")
    rain_probability: Mapped[float] = mapped_column(Float, default=0)
    created_at: Mapped[datetime | None] = mapped_column(DateTime, default=utcnow)


class PlantingAssessment(Base):
    __tablename__ = "planting_assessments"

    assessment_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    farm_id: Mapped[int] = mapped_column(ForeignKey("farms.farm_id"), index=True)
    reading_id: Mapped[int] = mapped_column(ForeignKey("climate_readings.reading_id"))
    planting_status: Mapped[str] = mapped_column(String(20))
    reason: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime | None] = mapped_column(DateTime, default=utcnow)


class ProductivityRecord(Base):
    __tablename__ = "productivity_records"
    __table_args__ = (Index("ix_productivity_farm_date", "farm_id", "harvest_date"),)

    productivity_id: Mapped[int] = mapped_column("record_id", Integer, primary_key=True)
    farm_id: Mapped[int] = mapped_column(ForeignKey("farms.farm_id"))
    crop_name: Mapped[str] = mapped_column(String(100))
    harvested_sacks: Mapped[int] = mapped_column(Integer)
    sold_sacks: Mapped[int] = mapped_column(Integer)
    price_per_sack: Mapped[float] = mapped_column(Numeric(12, 2, asdecimal=False))
    production_cost: Mapped[float] = mapped_column(Numeric(14, 2, asdecimal=False))
    harvest_date: Mapped[date] = mapped_column(Date)
    created_at: Mapped[datetime | None] = mapped_column(DateTime, default=utcnow)


class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"
    reset_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    used: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow, nullable=False)
