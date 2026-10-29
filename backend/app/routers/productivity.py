from collections import defaultdict

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_owned_farm
from ..models import Farm, ProductivityRecord, User
from ..schemas import ProductivityInput
from ..security import get_current_user, is_admin
from ..services.advisor import evaluate_harvest

router = APIRouter(prefix="/productivity", tags=["Crop productivity"])


def record_out(r: ProductivityRecord, area: float | None) -> dict:
    sales, profit, status, message, message_en = evaluate_harvest(
        r.sold_sacks, r.price_per_sack, r.production_cost
    )
    return {
       "record_id": r.productivity_id,
        "farm_id": r.farm_id,
        "crop_name": r.crop_name,
        "harvested_sacks": r.harvested_sacks,
        "sold_sacks": r.sold_sacks,
        "price_per_sack": float(r.price_per_sack),
        "production_cost": float(r.production_cost),
        "harvest_date": r.harvest_date.isoformat(),
        "created_at": r.created_at.isoformat() if r.created_at else None,
        "total_sales": sales,
        "estimated_profit": profit,
        "performance_status": status,
        "performance_message": message,
        "performance_message_en": message_en,
        "roi_percent": round(profit / r.production_cost * 100, 1) if r.production_cost else None,
        "yield_sacks_per_ha": round(float(r.harvested_sacks) / float(area), 2) if area else None,
    }


@router.post("/evaluate")
def evaluate_productivity(
    data: ProductivityInput, db: Session = Depends(get_db), user: User = Depends(get_current_user)
):
    if data.sold_sacks > data.harvested_sacks:
        raise HTTPException(status_code=400, detail="Sold sacks cannot exceed harvested sacks.")
    farm = get_owned_farm(data.farm_id, db, user)

    record = ProductivityRecord(**data.model_dump())
    db.add(record)
    db.commit()
    db.refresh(record)

    out = record_out(record, farm.area_hectares)
    return {"message": out["performance_message"], "record": out, **out}


@router.get("/records")
def list_records(
    farm_id: int = Query(..., gt=0),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    farm = get_owned_farm(farm_id, db, user)
    rows = db.scalars(
        select(ProductivityRecord).where(ProductivityRecord.farm_id == farm.farm_id)
        .order_by(ProductivityRecord.created_at.desc(), ProductivityRecord.productivity_id.desc())
        .limit(limit).offset(offset)
    ).all()
    records = [record_out(r, farm.area_hectares) for r in rows]
    return {"farm_id": farm.farm_id, "total_records": len(records), "records": records}


@router.delete("/records/{record_id}")
def delete_record(
    record_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)
):
    record = db.get(ProductivityRecord, record_id)
    farm = db.get(Farm, record.farm_id) if record else None
    if record is None or farm is None or (farm.farmer_id != user.user_id and not is_admin(user)):
        raise HTTPException(status_code=404, detail="Record not found.")
    db.delete(record)
    db.commit()
    return {"message": "Record deleted."}


@router.get("/summary")
def summary(
    farm_id: int = Query(..., gt=0),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    farm = get_owned_farm(farm_id, db, user)
    rows = db.scalars(
        select(ProductivityRecord).where(ProductivityRecord.farm_id == farm.farm_id)
        .order_by(ProductivityRecord.harvest_date)
    ).all()
    records = [record_out(r, farm.area_hectares) for r in rows]

    by_crop: dict[str, dict] = defaultdict(lambda: {"harvests": 0, "harvested_sacks": 0, "sales": 0.0, "profit": 0.0})
    for r in records:
        c = by_crop[r["crop_name"]]
        c["harvests"] += 1
        c["harvested_sacks"] += r["harvested_sacks"]
        c["sales"] = round(c["sales"] + r["total_sales"], 2)
        c["profit"] = round(c["profit"] + r["estimated_profit"], 2)

    total_cost = sum(r["production_cost"] for r in records)
    total_profit = round(sum(r["estimated_profit"] for r in records), 2)
    yields = [r["yield_sacks_per_ha"] for r in records if r["yield_sacks_per_ha"] is not None]

    return {
        "farm_id": farm.farm_id,
        "total_records": len(records),
        "total_harvested_sacks": sum(r["harvested_sacks"] for r in records),
        "total_sales": round(sum(r["total_sales"] for r in records), 2),
        "total_production_cost": round(total_cost, 2),
        "total_profit": total_profit,
        "overall_roi_percent": round(total_profit / total_cost * 100, 1) if total_cost else None,
        "profitable_harvests": sum(1 for r in records if r["estimated_profit"] > 0),
        "average_yield_sacks_per_ha": round(sum(yields) / len(yields), 2) if yields else None,
        "by_crop": [{"crop_name": k, **v} for k, v in sorted(by_crop.items())],
        "trend": [
            {"harvest_date": r["harvest_date"], "harvested_sacks": r["harvested_sacks"],
             "estimated_profit": r["estimated_profit"]}
            for r in records
        ],
    }
