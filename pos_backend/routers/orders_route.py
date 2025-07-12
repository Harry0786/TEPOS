from fastapi import APIRouter, HTTPException, status
from database.database import get_database
from typing import List
from datetime import datetime
from bson import ObjectId
import asyncio
import uuid
from services.websocket_service import websocket_manager
from models.estimate import EstimateCreate

router = APIRouter(
    prefix="/orders",
    tags=["orders"]
)

@router.get("/all")
async def get_all_orders():
    """Get all orders (estimates + completed sales)"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        
        # Get all estimates
        estimates = await estimates_collection.find().sort("created_at", -1).to_list(length=None)
        
        # Convert estimates to orders format
        orders = []
        for estimate in estimates:
            order = {
                "id": str(estimate["_id"]),
                "estimate_number": estimate.get("estimate_number", ""),
                "customer_name": estimate.get("customer_name", ""),
                "customer": estimate.get("customer_name", ""),  # For compatibility
                "total": estimate.get("total", 0.0),
                "amount": estimate.get("total", 0.0),  # For compatibility
                "status": estimate.get("status", "Pending"),
                "items": estimate.get("items", []),
                "items_count": len(estimate.get("items", [])),
                "created_at": estimate.get("created_at", datetime.now()),
                "time": estimate.get("created_at", datetime.now()).strftime("%Y-%m-%d") if isinstance(estimate.get("created_at"), datetime) else str(estimate.get("created_at", "")).split(" ")[0],
                "sale_by": estimate.get("sale_by", ""),
                "customer_phone": estimate.get("customer_phone", ""),
                "customer_address": estimate.get("customer_address", ""),
                "subtotal": estimate.get("subtotal", 0.0),
                "discount_amount": estimate.get("discount_amount", 0.0),
                "is_percentage_discount": estimate.get("is_percentage_discount", False),
                "discount_percentage": estimate.get("discount_percentage", 0.0),
            }
            orders.append(order)
        
        return orders
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching orders: {str(e)}"
        )

@router.put("/{estimate_id}/status")
async def update_order_status(estimate_id: str, status: str):
    """Update order/estimate status"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        
        # Update the estimate status
        result = await estimates_collection.update_one(
            {"_id": ObjectId(estimate_id)},
            {"$set": {"status": status}}
        )
        
        if result.modified_count > 0:
            # Notify all WebSocket clients of the update
            asyncio.create_task(websocket_manager.broadcast_update("order_updated"))
            
            return {
                "success": True,
                "message": f"Order status updated to {status}",
                "status": status
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Order not found"
            )
            
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error updating order status: {str(e)}"
        )

async def get_next_sale_number():
    """Get the next sequential sale number"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        
        # Find the highest sale number (sales have status "Completed")
        pipeline = [
            {
                "$match": {
                    "status": "Completed",
                    "sale_number": {"$exists": True, "$ne": None}
                }
            },
            {
                "$addFields": {
                    "numeric_part": {
                        "$toInt": {
                            "$substr": ["$sale_number", 1, -1]  # Remove # and convert to int
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
            # Extract the number from the highest sale number
            highest_number = result[0]["numeric_part"]
            next_number = highest_number + 1
        else:
            # No completed sales exist, start with 1
            next_number = 1
        
        # Format as #001, #002, etc.
        return f"#{next_number:03d}"
        
    except Exception as e:
        print(f"Error getting next sale number: {e}")
        # Fallback: use timestamp-based number
        return f"#{datetime.now().strftime('%Y%m%d%H%M%S')}"

@router.post("/create-sale", status_code=status.HTTP_201_CREATED)
async def create_completed_sale(sale_data: EstimateCreate):
    """Create a new completed sale"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        
        # Convert to dict and add timestamp
        sale_dict = sale_data.model_dump()
        
        # Set created_at if not provided
        if not sale_dict.get("created_at"):
            sale_dict["created_at"] = datetime.now()
        else:
            # Convert string to datetime if provided as string
            if isinstance(sale_dict["created_at"], str):
                sale_dict["created_at"] = datetime.fromisoformat(sale_dict["created_at"].replace('Z', '+00:00'))
        
        # Generate unique sale ID and sequential sale number
        sale_dict["sale_id"] = f"SALE-{uuid.uuid4().hex[:8].upper()}"
        sale_dict["sale_number"] = await get_next_sale_number()
        sale_dict["status"] = "Completed"  # Mark as completed sale
        
        # Calculate discount percentage if not provided
        if sale_dict.get("discount_percentage") is None:
            if sale_dict["is_percentage_discount"]:
                sale_dict["discount_percentage"] = sale_dict["discount_amount"]
            else:
                # Calculate percentage from fixed amount
                if sale_dict["subtotal"] > 0:
                    sale_dict["discount_percentage"] = (sale_dict["discount_amount"] / sale_dict["subtotal"]) * 100
                else:
                    sale_dict["discount_percentage"] = 0.0
        
        # Insert into database
        result = await estimates_collection.insert_one(sale_dict)
        
        if result.inserted_id:
            # Notify all WebSocket clients of the update
            asyncio.create_task(websocket_manager.broadcast_update("sale_completed"))
            return {
                "success": True,
                "message": "Sale completed successfully!",
                "data": {
                    "sale_id": sale_dict["sale_id"],
                    "sale_number": sale_dict["sale_number"],
                    "customer_name": sale_dict["customer_name"],
                    "total": sale_dict["total"],
                    "created_at": sale_dict["created_at"].isoformat()
                },
                "sale_id": sale_dict["sale_id"],
                "sale_number": sale_dict["sale_number"]
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create sale"
            )
            
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error creating sale: {str(e)}"
        )