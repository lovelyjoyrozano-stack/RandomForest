from fastapi import Depends, HTTPException
from sqlalchemy.orm import Session

from .database import get_db
from .models import Farm, User
from .security import get_current_user, is_admin


def get_owned_farm(farm_id: int, db: Session, user: User) -> Farm:
    """Return the farm if the user owns it (admins can see any).
    Missing and not-yours both give 404 so IDs cannot be probed."""
    farm = db.get(Farm, farm_id)
    if farm is None or (farm.farmer_id != user.user_id and not is_admin(user)):
        raise HTTPException(status_code=404, detail="Farm not found.")
    return farm


__all__ = ["get_db", "get_current_user", "get_owned_farm", "Depends"]
