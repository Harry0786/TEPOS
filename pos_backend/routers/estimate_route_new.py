from fastapi import APIRouter, HTTPException, status
from models.estimate import EstimateCreate, EstimateResponse
from database.database import get_database
from typing import List, Optional
from datetime import datetime
from bson import ObjectId
import uuid
import asyncio
from services.websocket_service import websocket_manager

router = APIRouter(
    prefix="/estimates",
    tags=["estimates"]
)

def get_next_estimate_number():
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
        
        # Execute aggregation and convert to list
        cursor = estimates_collection.aggregate(pipeline)
        result = list(cursor)
        
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
        return f"#{datetime.now().strftime('%Y%m%d%H%M%S')}"

@router.post("/create", status_code=status.HTTP_201_CREATED)
def create_estimate(estimate_data: EstimateCreate):
    """Create a new estimate"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        
        # Convert to dict and add timestamp
        estimate_dict = estimate_data.model_dump()
        
        # Set created_at if not provided
        if not estimate_dict.get("created_at"):
            estimate_dict["created_at"] = datetime.now()
        else:
            # Convert string to datetime if provided as string
            if isinstance(estimate_dict["created_at"], str):
                estimate_dict["created_at"] = datetime.fromisoformat(estimate_dict["created_at"].replace('Z', '+00:00'))
        
        # Generate unique estimate ID and sequential estimate number
        estimate_dict["estimate_id"] = f"EST-{uuid.uuid4().hex[:8].upper()}"
        estimate_dict["estimate_number"] = get_next_estimate_number()
        
        # Initialize conversion tracking fields
        estimate_dict["is_converted_to_order"] = False
        estimate_dict["linked_order_id"] = None
        estimate_dict["linked_order_number"] = None
        
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
        result = estimates_collection.insert_one(estimate_dict)
        
        if result.inserted_id:
            # Notify all WebSocket clients of the update
            try:
                import asyncio
                asyncio.create_task(websocket_manager.broadcast_update({
                    "type": "estimate",
                    "action": "create",
                    "id": estimate_dict["estimate_id"],
                    "data": {
                        "estimate_id": estimate_dict["estimate_id"],
                        "estimate_number": estimate_dict["estimate_number"],
                        "customer_name": estimate_dict["customer_name"],
                        "total": estimate_dict["total"],
                        "created_at": estimate_dict["created_at"].isoformat()
                    }
                }))
            except Exception as ws_error:
                print(f"⚠️ WebSocket notification failed: {ws_error}")
                # Continue even if WebSocket fails
            
            return {
                "success": True,
                "message": "Estimate created successfully!",
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
def get_all_estimates():
    """Get all estimates with conversion status"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        
        estimates = list(estimates_collection.find().sort("created_at", -1))
        
        # Convert ObjectId to string for each estimate and add conversion status
        for estimate in estimates:
            estimate["id"] = str(estimate["_id"])
            del estimate["_id"]  # Remove the ObjectId field
            
            # Add conversion status if not present
            if "is_converted_to_order" not in estimate:
                estimate["is_converted_to_order"] = False
            if "linked_order_id" not in estimate:
                estimate["linked_order_id"] = None
            if "linked_order_number" not in estimate:
                estimate["linked_order_number"] = None
        
        return estimates
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching estimates: {str(e)}"
        )

@router.get("/number/{estimate_number}")
def get_estimate_by_number(estimate_number: str):
    """Get estimate by estimate number (e.g., #001)"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        
        estimate = estimates_collection.find_one({"estimate_number": estimate_number})
        
        if not estimate:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Estimate not found"
            )
        
        # Convert ObjectId to string
        estimate["_id"] = str(estimate["_id"])
        
        # Add conversion status if not present
        if "is_converted_to_order" not in estimate:
            estimate["is_converted_to_order"] = False
        if "linked_order_id" not in estimate:
            estimate["linked_order_id"] = None
        if "linked_order_number" not in estimate:
            estimate["linked_order_number"] = None
            
        return estimate
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching estimate: {str(e)}"
        )

@router.get("/{estimate_id}")
def get_estimate_by_id(estimate_id: str):
    """Get estimate by ID"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        
        estimate = estimates_collection.find_one({"estimate_id": estimate_id})
        
        if not estimate:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Estimate not found"
            )
        
        # Convert ObjectId to string
        estimate["_id"] = str(estimate["_id"])
        
        # Add conversion status if not present
        if "is_converted_to_order" not in estimate:
            estimate["is_converted_to_order"] = False
        if "linked_order_id" not in estimate:
            estimate["linked_order_id"] = None
        if "linked_order_number" not in estimate:
            estimate["linked_order_number"] = None
            
        return estimate
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching estimate: {str(e)}"
        )

@router.delete("/{estimate_id}")
def delete_estimate(estimate_id: str):
    """Delete an estimate"""
    try:
        print(f"🗑️ Starting estimate deletion: {estimate_id}")
        db = get_database()
        estimates_collection = db.estimates
        estimate = estimates_collection.find_one({"estimate_id": estimate_id})
        if not estimate:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Estimate not found"
            )
        if estimate.get("is_converted_to_order", False):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot delete estimate that has been converted to order"
            )
        result = estimates_collection.delete_one({"estimate_id": estimate_id})
        if result.deleted_count > 0:
            import asyncio
            try:
                asyncio.create_task(websocket_manager.broadcast_update({
                    "type": "estimate",
                    "action": "delete",
                    "id": estimate_id
                }))
            except Exception as ws_error:
                print(f"⚠️ WebSocket notification failed: {ws_error}")
            return {
                "success": True,
                "message": "Estimate deleted successfully"
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to delete estimate"
            )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error deleting estimate: {str(e)}"
        )

@router.post("/{estimate_id}/convert-to-order")
def convert_estimate_to_order(estimate_id: str, payment_mode: str = "Cash", sale_by: Optional[str] = None):
    """Convert an estimate to an order"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        orders_collection = db.orders
        estimate = estimates_collection.find_one({"estimate_id": estimate_id})
        if not estimate:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Estimate not found"
            )
        if estimate.get("is_converted_to_order", False):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Estimate has already been converted to order"
            )
        order_data = {
            "customer_name": estimate["customer_name"],
            "customer_phone": estimate["customer_phone"],
            "customer_address": estimate["customer_address"],
            "sale_by": sale_by if sale_by is not None else estimate["sale_by"],
            "items": estimate["items"],
            "subtotal": estimate["subtotal"],
            "discount_amount": estimate["discount_amount"],
            "is_percentage_discount": estimate["is_percentage_discount"],
            "discount_percentage": estimate.get("discount_percentage"),
            "total": estimate["total"],
            "payment_mode": payment_mode,
            "created_at": datetime.now(),
            "source_estimate_id": estimate["estimate_id"],
            "source_estimate_number": estimate["estimate_number"]
        }
        order_data["order_id"] = f"ORDER-{uuid.uuid4().hex[:8].upper()}"
        from routers.orders_route_new import get_next_sale_number
        order_data["sale_number"] = get_next_sale_number()
        order_data["status"] = "Completed"
        order_data["is_from_estimate"] = True
        order_result = orders_collection.insert_one(order_data)
        if order_result.inserted_id:
            estimates_collection.update_one(
                {"estimate_id": estimate_id},
                {"$set": {
                    "is_converted_to_order": True,
                    "linked_order_id": order_data["order_id"],
                    "linked_order_number": order_data["sale_number"]
                }}
            )
            import asyncio
            asyncio.create_task(websocket_manager.broadcast_update({
                "type": "estimate",
                "action": "convert_to_order",
                "id": estimate_id,
                "order_id": order_data["order_id"],
                "order_number": order_data["sale_number"]
            }))
            return {
                "success": True,
                "message": "Estimate converted to order successfully!",
                "data": {
                    "order_id": order_data["order_id"],
                    "sale_number": order_data["sale_number"],
                    "estimate_id": estimate["estimate_id"],
                    "estimate_number": estimate["estimate_number"],
                    "customer_name": order_data["customer_name"],
                    "total": order_data["total"],
                    "payment_mode": payment_mode,
                    "created_at": order_data["created_at"].isoformat()
                },
                "order_id": order_data["order_id"],
                "sale_number": order_data["sale_number"]
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create order from estimate"
            )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error converting estimate to order: {str(e)}"
        )

@router.get("/converted")
def get_converted_estimates():
    """Get all estimates that have been converted to orders"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        
        estimates = list(estimates_collection.find({
            "is_converted_to_order": True
        }).sort("created_at", -1))
        
        # Convert ObjectId to string for each estimate
        for estimate in estimates:
            estimate["id"] = str(estimate["_id"])
            del estimate["_id"]
        
        return estimates
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching converted estimates: {str(e)}"
        )

@router.get("/pending")
def get_pending_estimates():
    """Get all estimates that have not been converted to orders"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        
        estimates = list(estimates_collection.find({
            "is_converted_to_order": {"$ne": True}
        }).sort("created_at", -1))
        
        # Convert ObjectId to string for each estimate
        for estimate in estimates:
            estimate["id"] = str(estimate["_id"])
            del estimate["_id"]
        
        return estimates
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching pending estimates: {str(e)}"
        ) 