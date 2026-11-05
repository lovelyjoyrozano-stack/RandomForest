
import secrets
import httpx

import json
import re
import unicodedata
from functools import lru_cache
from pathlib import Path

from shapely.geometry import shape
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..config import get_settings
from ..database import get_db
from ..deps import get_owned_farm
from ..models import (
    Farm,
    User,
    ClimateReading,
    PlantingAssessment,
    ProductivityRecord,
)
from ..schemas import FarmCreate, FarmOut, FarmUpdate
from ..security import get_current_user, is_admin


router = APIRouter(prefix="/farms", tags=["Farms"])

GEOCODING_URL = "https://api.openweathermap.org/geo/1.0/direct"


# --------------------------------------------------
# GEOCODING HELPER
# --------------------------------------------------

# --------------------------------------------------
# CABADBARAN BARANGAY COORDINATES
# --------------------------------------------------

GEOJSON_PATH = Path(__file__).resolve().parent.parent / "data" / "barangays.geojson"


def normalize_location(value: str) -> str:
    value = unicodedata.normalize("NFKD", value)
    value = "".join(c for c in value if not unicodedata.combining(c))
    value = value.lower().strip()
    value = re.sub(r"[^a-z0-9 ]", " ", value)
    return " ".join(value.split())


@lru_cache(maxsize=1)
def load_cabadbaran_barangays():
    if not GEOJSON_PATH.exists():
        return {}

    try:
        with GEOJSON_PATH.open("r", encoding="utf-8") as file:
            geojson = json.load(file)

        barangays = {}

        for feature in geojson.get("features", []):
            properties = feature.get("properties") or {}
            geometry = feature.get("geometry")

            if not geometry:
                continue

            barangay_name = (
                properties.get("psgc_name")
                or properties.get("ADM4_EN")
                or properties.get("name")
            )

            municipality = (
                properties.get("ADM3_EN")
                or properties.get("adm3_en")
                or properties.get("municipality")
                or properties.get("city")
                or ""
            )

            province = (
                properties.get("ADM2_EN")
                or properties.get("adm2_en")
                or properties.get("province")
                or ""
            )

            if not barangay_name:
                continue

            if "cabadbaran" not in normalize_location(municipality):
                continue

            if province and "agusan del norte" not in normalize_location(province):
                continue

            polygon = shape(geometry)

            if polygon.is_empty or not polygon.is_valid:
                continue

            # Representative point is guaranteed to be inside the polygon.
            point = polygon.representative_point()

            barangays[normalize_location(barangay_name)] = (
                float(point.y),  # latitude
                float(point.x),  # longitude
            )

        return barangays

    except (OSError, ValueError, TypeError):
        return {}


# --------------------------------------------------
# GEOCODING HELPER
# --------------------------------------------------

def geocode_farm_location(
    location: str,
    city: str | None = None,
):
    """
    Get coordinates using the Cabadbaran barangay dataset first.
    Use OpenWeather geocoding as fallback.
    """

    selected_city = city or get_settings().default_city

    # Check if the location belongs to Cabadbaran.
    if "cabadbaran" in normalize_location(selected_city):
        # Supports entries such as "Soriano" or "Soriano, Cabadbaran".
        barangay_input = location.split(",")[0].strip()
        normalized = normalize_location(barangay_input)

        barangays = load_cabadbaran_barangays()

        if normalized in barangays:
            return barangays[normalized]

    # Fallback to OpenWeather geocoding.
    settings = get_settings()

    if not settings.openweather_api_key:
        return None

    query = (
        f"{location}, {selected_city}, "
        f"{settings.default_country}"
    )

    try:
        response = httpx.get(
            GEOCODING_URL,
            params={
                "q": query,
                "limit": 1,
                "appid": settings.openweather_api_key,
            },
            timeout=15,
        )

        response.raise_for_status()
        results = response.json()

        if not results:
            return None

        return (
            float(results[0]["lat"]),
            float(results[0]["lon"]),
        )

    except (httpx.HTTPError, ValueError, KeyError, TypeError):
        return None

# --------------------------------------------------
# LIST ALL FARMS
# --------------------------------------------------

@router.get("", response_model=list[FarmOut])
def list_farms(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    query = select(Farm).order_by(Farm.farm_id)

    if not is_admin(user):
        query = query.where(Farm.farmer_id == user.user_id)

    return db.scalars(query).all()


# --------------------------------------------------
# REGISTER FARM
# --------------------------------------------------

@router.post("", response_model=dict, status_code=201)
def create_farm(
    data: FarmCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if is_admin(user):
        raise HTTPException(
            status_code=403,
            detail="Only farmer accounts can register farms.",
        )

    settings = get_settings()

    selected_city = data.city or settings.default_city

    # Geocoding is optional.
    # Farm registration will continue even if coordinates are unavailable.
    coordinates = geocode_farm_location(
        data.location,
        selected_city,
    )

    latitude = coordinates[0] if coordinates else None
    longitude = coordinates[1] if coordinates else None

    farm = Farm(
        farmer_id=user.user_id,
        farm_code=data.farm_code or (
            f"FARM-{secrets.token_hex(3).upper()}"
        ),
        farm_name=data.farm_name,
        location=data.location,
        area_hectares=data.area_hectares,
        city=selected_city,
        latitude=latitude,
        longitude=longitude,
        status="Active",
    )

    db.add(farm)

    try:
        db.commit()
        db.refresh(farm)

    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Farm code already exists.",
        )

    return {
        "message": "Farm registered successfully.",
        "coordinates_available": coordinates is not None,
        "farm": FarmOut.model_validate(farm),
    }


# --------------------------------------------------
# GET ONE FARM
# --------------------------------------------------

@router.get("/{farm_id}", response_model=FarmOut)
def get_farm(
    farm_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return get_owned_farm(farm_id, db, user)


# --------------------------------------------------
# UPDATE FARM
# --------------------------------------------------

@router.patch("/{farm_id}", response_model=FarmOut)
def update_farm(
    farm_id: int,
    data: FarmUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    farm = get_owned_farm(farm_id, db, user)

    updates = data.model_dump(exclude_unset=True)

    new_location = updates.get("location", farm.location)
    new_city = updates.get(
        "city",
        farm.city or get_settings().default_city,
    )

    location_changed = (
        new_location != farm.location
        or new_city != farm.city
    )

    if location_changed:
        coordinates = geocode_farm_location(
            new_location,
            new_city,
        )

        if coordinates:
            farm.latitude = coordinates[0]
            farm.longitude = coordinates[1]
        else:
            # Do not retain coordinates from the old location.
            farm.latitude = None
            farm.longitude = None

    for field, value in updates.items():
        if value is not None:
            setattr(farm, field, value)

    if location_changed:
        farm.city = new_city

    try:
        db.commit()
        db.refresh(farm)

    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Unable to update farm. Please check the farm information.",
        )

    return farm


# --------------------------------------------------
# GEOCODE EXISTING FARM
# --------------------------------------------------

@router.post("/{farm_id}/geocode", response_model=FarmOut)
def geocode_existing_farm(
    farm_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    farm = get_owned_farm(farm_id, db, user)

    coordinates = geocode_farm_location(
        farm.location,
        farm.city,
    )

    if coordinates is None:
        raise HTTPException(
            status_code=422,
            detail=(
                "Unable to find coordinates for this farm. "
                "Please check the farm location and city."
            ),
        )

    farm.latitude = coordinates[0]
    farm.longitude = coordinates[1]

    db.commit()
    db.refresh(farm)

    return farm


# --------------------------------------------------
# DELETE FARM AND RELATED RECORDS
# --------------------------------------------------

@router.delete("/{farm_id}")
def delete_farm(
    farm_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    farm = get_owned_farm(farm_id, db, user)

    try:
        # 1. Delete planting assessments.
        db.execute(
            delete(PlantingAssessment).where(
                PlantingAssessment.farm_id == farm_id
            )
        )

        # 2. Delete climate readings.
        db.execute(
            delete(ClimateReading).where(
                ClimateReading.farm_id == farm_id
            )
        )

        # 3. Delete productivity records.
        db.execute(
            delete(ProductivityRecord).where(
                ProductivityRecord.farm_id == farm_id
            )
        )

        # 4. Delete the farm.
        db.delete(farm)

        db.commit()

    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail=(
                "The farm cannot be deleted because other database "
                "records still reference it."
            ),
        )

    except Exception:
        db.rollback()
        raise

    return {
        "message": "Farm and its related records deleted successfully.",
        "farm_id": farm_id,
    }
