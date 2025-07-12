from fastapi import APIRouter, HTTPException, status
from database.database import get_database
from typing import List
from datetime import datetime
from bson import ObjectId
import asyncio
from services.websocket_service import websocket_manager

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