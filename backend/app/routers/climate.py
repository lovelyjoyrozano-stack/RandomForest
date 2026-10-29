from datetime import timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import get_settings
from ..database import get_db
from ..deps import get_owned_farm
from ..models import ClimateReading, PlantingAssessment, User, utcnow
from ..schemas import ClimateInput
from ..security import get_current_user
from ..services import advisor, weather

router = APIRouter(tags=["Climate"])

# The forecast only changes every 3 hours; don't store a near-duplicate row on every refresh.
SAVE_INTERVAL = timedelta(minutes=30)


def _save(db: Session, farm_id: int, *, temperature, rainfall, humidity, condition, pop, status, reason) -> int:
    reading = ClimateReading(
        farm_id=farm_id, temperature=round(temperature, 2), rainfall=round(rainfall, 2),
        humidity=round(humidity, 2), weather_condition=condition, rain_probability=round(pop, 2),
    )
    db.add(reading)
    db.flush()
    db.add(PlantingAssessment(
        farm_id=farm_id, reading_id=reading.reading_id, planting_status=status, reason=reason,
    ))
    db.commit()
    return reading.reading_id


@router.get("/weather/forecast")
def weather_forecast(
    city: str | None = Query(default=None, min_length=1, max_length=100),
    _: User = Depends(get_current_user),
):
    summary = weather.get_summary(city or get_settings().default_city)
    return {
        "city": summary.city,
        "forecast_type": "Next 24 hours, 3-hour intervals",
        "forecasts": summary.periods,
    }

@router.get("/climate/current-weather")
def current_weather(
    farm_id: int = Query(..., gt=0),
    city: str | None = Query(default=None, min_length=1, max_length=100),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    farm = get_owned_farm(farm_id, db, user)
    selected_city = city or farm.city or get_settings().default_city

    return weather.get_current_weather(selected_city)

@router.get("/climate/planting-advice")
def planting_advice(
    farm_id: int = Query(..., gt=0),
    city: str | None = Query(default=None, min_length=1, max_length=100),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    farm = get_owned_farm(farm_id, db, user)
    city = city or farm.city or get_settings().default_city
    s = weather.get_summary(city)

    status, reason = advisor.assess_planting(
        s.avg_temperature, s.total_rainfall, s.max_rain_probability,
        has_thunderstorm=any("thunderstorm" in c for c in s.main_conditions),
    )

    latest = db.scalar(
        select(ClimateReading).where(ClimateReading.farm_id == farm.farm_id)
        .order_by(ClimateReading.reading_id.desc()).limit(1)
    )
    saved = latest is None or latest.created_at is None or utcnow() - latest.created_at >= SAVE_INTERVAL
    if saved:
        reading_id = _save(
            db, farm.farm_id, temperature=s.avg_temperature, rainfall=s.total_rainfall,
            humidity=s.avg_humidity, condition=s.weather_condition,
            pop=s.max_rain_probability, status=status, reason=reason,
        )
    else:
        reading_id = latest.reading_id

    return {
        "message": "Planting advice generated." + (" Saved." if saved else " (Recently saved; not duplicated.)"),
        "saved": saved,
        "farm_id": farm.farm_id,
        "city": s.city,
        "crop_name": "Rice",
        "forecast_periods_analyzed": len(s.periods),
        "average_temperature_c": round(s.avg_temperature, 2),
        "forecast_rainfall_mm": round(s.total_rainfall, 2),
        "average_humidity_percent": round(s.avg_humidity, 2),
        "maximum_rain_probability_percent": round(s.max_rain_probability, 2),
        "weather_condition": s.weather_condition,
        "conditions_24h": s.conditions_24h,
        "planting_status": status,
        "reason": reason,
        "reading_id": reading_id,
        "forecasts": s.periods,
    }


@router.post("/climate/assess")
def assess_climate(
    data: ClimateInput, db: Session = Depends(get_db), user: User = Depends(get_current_user)
):
    """Manual assessment from readings the farmer types in (e.g. own rain gauge)."""
    farm = get_owned_farm(data.farm_id, db, user)
    status, reason = advisor.assess_planting(
        data.temperature, data.rainfall, data.rain_probability,
        has_thunderstorm="thunderstorm" in data.weather_condition.lower(),
    )
    reading_id = _save(
        db, farm.farm_id, temperature=data.temperature, rainfall=data.rainfall,
        humidity=data.humidity, condition=data.weather_condition,
        pop=data.rain_probability, status=status, reason=reason,
    )
    return {
        "message": "Climate assessment saved successfully",
        "reading_id": reading_id, "farm_id": farm.farm_id,
        "planting_status": status, "reason": reason,
    }


@router.get("/climate/history")
def climate_history(
    farm_id: int = Query(..., gt=0),
    limit: int = Query(30, ge=1, le=365),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    farm = get_owned_farm(farm_id, db, user)
    rows = db.execute(
        select(ClimateReading, PlantingAssessment.planting_status)
        .outerjoin(PlantingAssessment, PlantingAssessment.reading_id == ClimateReading.reading_id)
        .where(ClimateReading.farm_id == farm.farm_id)
        .order_by(ClimateReading.reading_id.desc()).limit(limit)
    ).all()
    return {
        "farm_id": farm.farm_id,
        "readings": [
            {
                "reading_id": r.reading_id,
                "created_at": r.created_at.isoformat() if r.created_at else None,
                "temperature": r.temperature, "rainfall": r.rainfall, "humidity": r.humidity,
                "weather_condition": r.weather_condition,
                "rain_probability": r.rain_probability, "planting_status": status,
            }
            for r, status in rows
        ],
    }
