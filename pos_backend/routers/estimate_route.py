from fastapi import APIRouter, HTTPException, status
from models.estimate import EstimateCreate, EstimateResponse
from database.database import get_database
from typing import List
from datetime import datetime, timezone
from bson import ObjectId
import uuid
import asyncio
from services.websocket_service import websocket_manager
from dateutil import tz

router = APIRouter(
    prefix="/estimates",
    tags=["estimates"]
)

async def get_next_estimate_number():
    """Get the next sequential estimate number"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        
        # Find the highest estimate number
        pipeline = [
            {
                "$match": {
                    "estimate_number": {"$exists": True, "$ne": None}
                }
            },
            {
                "$addFields": {
                    "numeric_part": {
                        "$toInt": {
                            "$substr": ["$estimate_number", 1, -1]  # Remove # and convert to int
                        }
                    }
                }
            },
            {
                "$sort": {"numeric_part": -1}
            },
            {
                "$limit": 1
            }
        ]
        
        result = await estimates_collection.aggregate(pipeline).to_list(length=1)
        
        if result:
            # Extract the number from the highest estimate number
            highest_number = result[0]["numeric_part"]
            next_number = highest_number + 1
        else:
            # No estimates exist, start with 1
            next_number = 1
        
        # Format as #001, #002, etc.
        return f"#{next_number:03d}"
        
    except Exception as e:
        print(f"Error getting next estimate number: {e}")
        # Fallback: use timestamp-based number
        ist = tz.gettz('Asia/Kolkata')
        return f"#{datetime.now(ist).strftime('%Y%m%d%H%M%S')}"

@router.post("/create", status_code=status.HTTP_201_CREATED)
async def create_estimate(estimate_data: EstimateCreate):
    """Create a new estimate"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        
        # Convert to dict and add timestamp
        estimate_dict = estimate_data.model_dump()
        
        # Set created_at if not provided
        if not estimate_dict.get("created_at"):
            ist = tz.gettz('Asia/Kolkata')
            estimate_dict["created_at"] = datetime.now(ist)
            print(f"[DEBUG] Estimate created_at (IST): {estimate_dict['created_at']}")
        else:
            # Convert string to datetime if provided as string
            if isinstance(estimate_dict["created_at"], str):
                ist = tz.gettz('Asia/Kolkata')
                estimate_dict["created_at"] = datetime.fromisoformat(estimate_dict["created_at"].replace('Z', '+05:30')).astimezone(ist)
                print(f"[DEBUG] Estimate created_at (from string, IST): {estimate_dict['created_at']}")
        
        # Generate unique estimate ID and sequential estimate number
        estimate_dict["estimate_id"] = f"EST-{uuid.uuid4().hex[:8].upper()}"
        estimate_dict["estimate_number"] = await get_next_estimate_number()
        
        # Calculate discount percentage if not provided
        if estimate_dict.get("discount_percentage") is None:
            if estimate_dict["is_percentage_discount"]:
                estimate_dict["discount_percentage"] = estimate_dict["discount_amount"]
            else:
                # Calculate percentage from fixed amount
                if estimate_dict["subtotal"] > 0:
                    estimate_dict["discount_percentage"] = (estimate_dict["discount_amount"] / estimate_dict["subtotal"]) * 100
                else:
                    estimate_dict["discount_percentage"] = 0.0
        
        # Insert into database
        result = await estimates_collection.insert_one(estimate_dict)
        
        if result.inserted_id:
            # Notify all WebSocket clients of the update
            asyncio.create_task(websocket_manager.broadcast_update("estimate_updated"))
            return {
                "success": True,
                "message": "Estimate sent successfully!",
                "data": {
                    "estimate_id": estimate_dict["estimate_id"],
                    "estimate_number": estimate_dict["estimate_number"],
                    "customer_name": estimate_dict["customer_name"],
                    "total": estimate_dict["total"],
                    "created_at": estimate_dict["created_at"].isoformat()
                },
                "estimate_id": estimate_dict["estimate_id"],
                "estimate_number": estimate_dict["estimate_number"]
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create estimate"
            )
            
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error creating estimate: {str(e)}"
        )

@router.get("/all")
async def get_all_estimates():
    """Get all estimates"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        
        estimates = await estimates_collection.find().sort("created_at", -1).to_list(length=None)
        
        # Convert ObjectId to string for each estimate and remove _id
        for estimate in estimates:
            estimate["id"] = str(estimate["_id"])
            del estimate["_id"]  # Remove the ObjectId field
            if "status" not in estimate:
                estimate["status"] = "Pending"
        
        return estimates
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching estimates: {str(e)}"
        )

@router.get("/number/{estimate_number}")
async def get_estimate_by_number(estimate_number: str):
    """Get estimate by estimate number (e.g., #001)"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        
        estimate = await estimates_collection.find_one({"estimate_number": estimate_number})
        
        if not estimate:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Estimate not found"
            )
        
        # Convert ObjectId to string
        estimate["_id"] = str(estimate["_id"])
            
        return estimate
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching estimate: {str(e)}"
        )

@router.get("/{estimate_id}")
async def get_estimate_by_id(estimate_id: str):
    """Get estimate by ID"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        
        estimate = await estimates_collection.find_one({"estimate_id": estimate_id})
        
        if not estimate:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Estimate not found"
            )
        
        # Convert ObjectId to string
        estimate["_id"] = str(estimate["_id"])
            
        return estimate
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching estimate: {str(e)}"
        )