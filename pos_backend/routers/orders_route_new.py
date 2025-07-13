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

def get_next_sale_number():
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
        
        result = list(orders_collection.aggregate(pipeline))
        
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
def create_completed_sale(order_data: OrderCreate):
    """Create a new completed sale"""
    try:
        print(f"🔄 Starting sale creation for customer: {order_data.customer_name}")
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
        
        print(f"📋 Generating order ID and sale number...")
        # Generate unique order ID and sequential sale number
        order_dict["order_id"] = f"ORDER-{uuid.uuid4().hex[:8].upper()}"
        
        # Add timeout for sale number generation
        try:
            order_dict["sale_number"] = get_next_sale_number()
        except Exception:
            print("⚠️ Error getting sale number, using fallback")
            order_dict["sale_number"] = f"#{datetime.now().strftime('%Y%m%d%H%M%S')}"
        
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
        
        print(f"💾 Inserting order into database...")
        # Insert into database with timeout
        result = orders_collection.insert_one(order_dict)
        
        if result.inserted_id:
            print(f"✅ Order created successfully: {order_dict['order_id']}")
            # Notify all WebSocket clients of the update
            try:
                import asyncio
                asyncio.create_task(websocket_manager.broadcast_update({
                    "type": "order",
                    "action": "create",
                    "id": order_dict["order_id"],
                    "data": {
                        "order_id": order_dict["order_id"],
                        "sale_number": order_dict["sale_number"],
                        "customer_name": order_dict["customer_name"],
                        "total": order_dict["total"],
                        "created_at": order_dict["created_at"].isoformat()
                    }
                }))
            except Exception as ws_error:
                print(f"⚠️ WebSocket notification failed: {ws_error}")
                # Continue even if WebSocket fails
            
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
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error creating sale: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error creating sale: {str(e)}"
        )

@router.get("/all")
def get_all_orders():
    """Get all orders (estimates + completed sales) - Legacy endpoint for compatibility"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        orders_collection = db.orders
        
        # Get all estimates
        estimates = list(estimates_collection.find().sort("created_at", -1))
        
        # Get all completed orders
        orders = list(orders_collection.find().sort("created_at", -1))
        
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

@router.get("/separate")
def get_orders_and_estimates_separate():
    """Get orders and estimates as separate lists"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        orders_collection = db.orders
        
        # Get all estimates
        estimates = list(estimates_collection.find().sort("created_at", -1))
        
        # Get all completed orders
        orders = list(orders_collection.find().sort("created_at", -1))
        
        # Convert ObjectIds to strings
        for estimate in estimates:
            estimate["_id"] = str(estimate["_id"])
        
        for order in orders:
            order["_id"] = str(order["_id"])
        
        return {
            "estimates": {
                "count": len(estimates),
                "total_amount": sum(e.get("total", 0) for e in estimates),
                "items": estimates
            },
            "orders": {
                "count": len(orders),
                "total_amount": sum(o.get("total", 0) for o in orders),
                "items": orders
            },
            "summary": {
                "total_estimates": len(estimates),
                "total_orders": len(orders),
                "total_transactions": len(estimates) + len(orders),
                "total_revenue": sum(e.get("total", 0) for e in estimates) + sum(o.get("total", 0) for o in orders)
            }
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching separate data: {str(e)}"
        )

@router.get("/orders-only")
def get_orders_only():
    """Get only completed orders"""
    try:
        db = get_database()
        orders_collection = db.orders
        
        # Get all completed orders
        orders = list(orders_collection.find().sort("created_at", -1))
        
        # Convert ObjectIds to strings
        for order in orders:
            order["_id"] = str(order["_id"])
        
        return {
            "orders": {
                "count": len(orders),
                "total_amount": sum(o.get("total", 0) for o in orders),
                "items": orders
            }
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching orders: {str(e)}"
        )

@router.get("/{order_id}")
def get_order_by_id(order_id: str):
    """Get order by ID"""
    try:
        db = get_database()
        orders_collection = db.orders
        
        order = orders_collection.find_one({"order_id": order_id})
        
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
def get_order_by_number(sale_number: str):
    """Get order by sale number (e.g., #001)"""
    try:
        db = get_database()
        orders_collection = db.orders
        
        order = orders_collection.find_one({"sale_number": sale_number})
        
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
def update_order_status(order_id: str, new_status: str):
    """Update order status"""
    try:
        db = get_database()
        orders_collection = db.orders
        
        # Update the order status
        result = orders_collection.update_one(
            {"order_id": order_id},
            {"$set": {"status": new_status}}
        )
        
        if result.modified_count > 0:
            # Notify all WebSocket clients of the update
            # WebSocket notification is still async, so use create_task if running in an event loop
            pass
            
            return {
                "success": True,
                "message": f"Order status updated to {new_status}",
                "status": new_status
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

@router.delete("/{order_id}")
def delete_order(order_id: str):
    """Delete an order and its linked estimate if it was created from an estimate"""
    try:
        db = get_database()
        orders_collection = db.orders
        estimates_collection = db.estimates
        
        # Check if order exists
        order = orders_collection.find_one({"order_id": order_id})
        if not order:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Order not found"
            )
        
        # Check if order was created from an estimate
        source_estimate_id = order.get("source_estimate_id")
        
        # Delete the order
        result = orders_collection.delete_one({"order_id": order_id})
        
        if result.deleted_count > 0:
            # If order was created from an estimate, also delete the estimate
            if source_estimate_id:
                try:
                    estimates_collection.delete_one({"estimate_id": source_estimate_id})
                    print(f"Deleted linked estimate: {source_estimate_id}")
                except Exception as e:
                    print(f"Warning: Failed to delete linked estimate {source_estimate_id}: {e}")
                    # Continue even if estimate deletion fails
            
            # Notify all WebSocket clients of the update
            try:
                import asyncio
                asyncio.create_task(websocket_manager.broadcast_update({
                    "type": "order",
                    "action": "delete",
                    "id": order_id
                }))
            except Exception as ws_error:
                print(f"⚠️ WebSocket notification failed: {ws_error}")
            
            return {
                "success": True,
                "message": "Order deleted successfully" + (" (linked estimate also deleted)" if source_estimate_id else "")
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to delete order"
            )
            
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error deleting order: {str(e)}"
        ) 