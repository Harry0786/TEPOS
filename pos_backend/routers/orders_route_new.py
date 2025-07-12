from fastapi import APIRouter, HTTPException, status
from database.database import get_database
from typing import List
from datetime import datetime
from bson import ObjectId
import asyncio
import uuid
from services.websocket_service import websocket_manager
from models.order import OrderCreate

router = APIRouter(
    prefix="/orders",
    tags=["orders"]
)

async def get_next_sale_number():
    """Get the next sequential sale number"""
    try:
        db = get_database()
        orders_collection = db.orders
        
        # Find the highest sale number
        pipeline = [
            {
                "$match": {
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
        
        result = await orders_collection.aggregate(pipeline).to_list(length=1)
        
        if result:
            # Extract the number from the highest sale number
            highest_number = result[0]["numeric_part"]
            next_number = highest_number + 1
        else:
            # No orders exist, start with 1
            next_number = 1
        
        # Format as #001, #002, etc.
        return f"#{next_number:03d}"
        
    except Exception as e:
        print(f"Error getting next sale number: {e}")
        # Fallback: use timestamp-based number
        return f"#{datetime.now().strftime('%Y%m%d%H%M%S')}"

@router.post("/create-sale", status_code=status.HTTP_201_CREATED)
async def create_completed_sale(order_data: OrderCreate):
    """Create a new completed sale"""
    try:
        db = get_database()
        orders_collection = db.orders
        
        # Convert to dict and add timestamp
        order_dict = order_data.model_dump()
        
        # Set created_at if not provided
        if not order_dict.get("created_at"):
            order_dict["created_at"] = datetime.now()
        else:
            # Convert string to datetime if provided as string
            if isinstance(order_dict["created_at"], str):
                order_dict["created_at"] = datetime.fromisoformat(order_dict["created_at"].replace('Z', '+00:00'))
        
        # Generate unique order ID and sequential sale number
        order_dict["order_id"] = f"ORDER-{uuid.uuid4().hex[:8].upper()}"
        order_dict["sale_number"] = await get_next_sale_number()
        order_dict["status"] = "Completed"  # Mark as completed sale
        
        # Calculate discount percentage if not provided
        if order_dict.get("discount_percentage") is None:
            if order_dict["is_percentage_discount"]:
                order_dict["discount_percentage"] = order_dict["discount_amount"]
            else:
                # Calculate percentage from fixed amount
                if order_dict["subtotal"] > 0:
                    order_dict["discount_percentage"] = (order_dict["discount_amount"] / order_dict["subtotal"]) * 100
                else:
                    order_dict["discount_percentage"] = 0.0
        
        # Insert into database
        result = await orders_collection.insert_one(order_dict)
        
        if result.inserted_id:
            # Notify all WebSocket clients of the update
            asyncio.create_task(websocket_manager.broadcast_update("sale_completed"))
            return {
                "success": True,
                "message": "Sale completed successfully!",
                "data": {
                    "order_id": order_dict["order_id"],
                    "sale_number": order_dict["sale_number"],
                    "customer_name": order_dict["customer_name"],
                    "total": order_dict["total"],
                    "created_at": order_dict["created_at"].isoformat()
                },
                "order_id": order_dict["order_id"],
                "sale_number": order_dict["sale_number"]
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

@router.get("/all")
async def get_all_orders():
    """Get all orders (estimates + completed sales)"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        orders_collection = db.orders
        
        # Get all estimates
        estimates = await estimates_collection.find().sort("created_at", -1).to_list(length=None)
        
        # Get all completed orders
        orders = await orders_collection.find().sort("created_at", -1).to_list(length=None)
        
        # Convert estimates to orders format
        all_orders = []
        
        # Add estimates
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
                "type": "estimate"
            }
            all_orders.append(order)
        
        # Add completed orders
        for order in orders:
            order_data = {
                "id": str(order["_id"]),
                "sale_number": order.get("sale_number", ""),
                "customer_name": order.get("customer_name", ""),
                "customer": order.get("customer_name", ""),  # For compatibility
                "total": order.get("total", 0.0),
                "amount": order.get("total", 0.0),  # For compatibility
                "status": order.get("status", "Completed"),
                "items": order.get("items", []),
                "items_count": len(order.get("items", [])),
                "created_at": order.get("created_at", datetime.now()),
                "time": order.get("created_at", datetime.now()).strftime("%Y-%m-%d") if isinstance(order.get("created_at"), datetime) else str(order.get("created_at", "")).split(" ")[0],
                "sale_by": order.get("sale_by", ""),
                "customer_phone": order.get("customer_phone", ""),
                "customer_address": order.get("customer_address", ""),
                "subtotal": order.get("subtotal", 0.0),
                "discount_amount": order.get("discount_amount", 0.0),
                "is_percentage_discount": order.get("is_percentage_discount", False),
                "discount_percentage": order.get("discount_percentage", 0.0),
                "payment_mode": order.get("payment_mode", "Cash"),
                "type": "order"
            }
            all_orders.append(order_data)
        
        # Sort by created_at descending
        all_orders.sort(key=lambda x: x["created_at"], reverse=True)
        
        return all_orders
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching orders: {str(e)}"
        )

@router.get("/{order_id}")
async def get_order_by_id(order_id: str):
    """Get order by ID"""
    try:
        db = get_database()
        orders_collection = db.orders
        
        order = await orders_collection.find_one({"order_id": order_id})
        
        if not order:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Order not found"
            )
        
        # Convert ObjectId to string
        order["_id"] = str(order["_id"])
            
        return order
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching order: {str(e)}"
        )

@router.get("/number/{sale_number}")
async def get_order_by_number(sale_number: str):
    """Get order by sale number (e.g., #001)"""
    try:
        db = get_database()
        orders_collection = db.orders
        
        order = await orders_collection.find_one({"sale_number": sale_number})
        
        if not order:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Order not found"
            )
        
        # Convert ObjectId to string
        order["_id"] = str(order["_id"])
            
        return order
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching order: {str(e)}"
        )

@router.put("/{order_id}/status")
async def update_order_status(order_id: str, status: str):
    """Update order status"""
    try:
        db = get_database()
        orders_collection = db.orders
        
        # Update the order status
        result = await orders_collection.update_one(
            {"order_id": order_id},
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