import secrets

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_owned_farm
from ..models import Farm, User
from ..schemas import FarmCreate, FarmOut, FarmUpdate
from ..security import get_current_user, is_admin

router = APIRouter(prefix="/farms", tags=["Farms"])


@router.get("", response_model=list[FarmOut])
def list_farms(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    query = select(Farm).order_by(Farm.farm_id)
    if not is_admin(user):
        query = query.where(Farm.farmer_id == user.user_id)
    return db.scalars(query).all()


@router.post("", response_model=dict, status_code=201)
def create_farm(data: FarmCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    if is_admin(user):
        raise HTTPException(status_code=403, detail="Only farmer accounts can register farms.")

    farm = Farm(
        farmer_id=user.user_id,
        farm_code=data.farm_code or f"FARM-{secrets.token_hex(3).upper()}",
        farm_name=data.farm_name,
        location=data.location,
        area_hectares=data.area_hectares,
        city=data.city,
        status="Active",
    )
    db.add(farm)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Farm code already exists.")
    db.refresh(farm)
    return {"message": "Farm registered successfully", "farm": FarmOut.model_validate(farm)}


@router.get("/{farm_id}", response_model=FarmOut)
def get_farm(farm_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    return get_owned_farm(farm_id, db, user)


@router.patch("/{farm_id}", response_model=FarmOut)
def update_farm(
    farm_id: int, data: FarmUpdate,
    db: Session = Depends(get_db), user: User = Depends(get_current_user),
):
    farm = get_owned_farm(farm_id, db, user)
    for field, value in data.model_dump(exclude_unset=True).items():
        if value is not None:
            setattr(farm, field, value)
    db.commit()
    db.refresh(farm)
    return farm
