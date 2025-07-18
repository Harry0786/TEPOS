from fastapi import APIRouter, HTTPException, status
from database.database import get_database
from typing import Dict, List, Any
from datetime import datetime, timedelta
from bson import ObjectId
import asyncio
from dateutil import tz

router = APIRouter(
    prefix="/reports",
    tags=["reports"]
)

@router.get("/today")
async def get_today_report():
    """Get today's report with separate counts for orders and estimates"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        orders_collection = db.orders
        
        ist = tz.gettz('Asia/Kolkata')
        # Get today's date range in IST
        today = datetime.now(ist).date()
        start_of_day = datetime.combine(today, datetime.min.time(), ist)
        end_of_day = datetime.combine(today, datetime.max.time(), ist)
        
        # Get today's estimates
        today_estimates = await estimates_collection.find({
            "created_at": {
                "$gte": start_of_day,
                "$lte": end_of_day
            }
        }).to_list(length=None)
        
        # Get today's orders
        today_orders = await orders_collection.find({
            "created_at": {
                "$gte": start_of_day,
                "$lte": end_of_day
            }
        }).to_list(length=None)
        
        # Calculate estimates statistics
        estimates_count = len(today_estimates)
        estimates_total = sum(estimate.get("total", 0) for estimate in today_estimates)
        estimates_converted = len([e for e in today_estimates if e.get("is_converted_to_order", False)])
        estimates_pending = estimates_count - estimates_converted
        
        # Calculate orders statistics with detailed payment breakdown
        orders_count = len(today_orders)
        orders_total = sum(order.get("total", 0) for order in today_orders)
        
        # Calculate payment mode breakdown with amounts
        payment_breakdown = {
            "cash": {"count": 0, "amount": 0.0},
            "card": {"count": 0, "amount": 0.0},
            "online": {"count": 0, "amount": 0.0},
            "upi": {"count": 0, "amount": 0.0},
            "bank_transfer": {"count": 0, "amount": 0.0},
            "cheque": {"count": 0, "amount": 0.0},
            "other": {"count": 0, "amount": 0.0}
        }
        
        for order in today_orders:
            payment_mode = order.get("payment_mode", "").lower()
            amount = order.get("total", 0) or order.get("amount", 0)
            
            if payment_mode in payment_breakdown:
                payment_breakdown[payment_mode]["count"] += 1
                payment_breakdown[payment_mode]["amount"] += amount
            else:
                payment_breakdown["other"]["count"] += 1
                payment_breakdown["other"]["amount"] += amount
        
        # Calculate overall statistics
        total_transactions = estimates_count + orders_count
        total_revenue = estimates_total + orders_total
        
        return {
            "date": today.isoformat(),
            "summary": {
                "total_transactions": total_transactions,
                "total_revenue": total_revenue,
                "estimates_count": estimates_count,
                "orders_count": orders_count
            },
            "estimates": {
                "count": estimates_count,
                "total_amount": estimates_total,
                "conversion_breakdown": {
                    "pending": estimates_pending,
                    "converted": estimates_converted
                },
                "items": today_estimates
            },
            "orders": {
                "count": orders_count,
                "total_amount": orders_total,
                "payment_breakdown": payment_breakdown,
                "items": today_orders
            }
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error generating today's report: {str(e)}"
        )

@router.get("/date-range")
async def get_date_range_report(start_date: str, end_date: str):
    """Get report for a specific date range"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        orders_collection = db.orders
        
        ist = tz.gettz('Asia/Kolkata')
        # Parse dates in IST for date range report
        start = datetime.fromisoformat(start_date).astimezone(ist)
        end = datetime.fromisoformat(end_date).astimezone(ist)
        
        # Get estimates in date range
        estimates = await estimates_collection.find({
            "created_at": {
                "$gte": start,
                "$lte": end
            }
        }).to_list(length=None)
        
        # Get orders in date range
        orders = await orders_collection.find({
            "created_at": {
                "$gte": start,
                "$lte": end
            }
        }).to_list(length=None)
        
        # Calculate statistics
        estimates_count = len(estimates)
        estimates_total = sum(estimate.get("total", 0) for estimate in estimates)
        orders_count = len(orders)
        orders_total = sum(order.get("total", 0) for order in orders)
        
        return {
            "date_range": {
                "start": start_date,
                "end": end_date
            },
            "summary": {
                "total_transactions": estimates_count + orders_count,
                "total_revenue": estimates_total + orders_total,
                "estimates_count": estimates_count,
                "orders_count": orders_count
            },
            "estimates": {
                "count": estimates_count,
                "total_amount": estimates_total,
                "items": estimates
            },
            "orders": {
                "count": orders_count,
                "total_amount": orders_total,
                "items": orders
            }
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error generating date range report: {str(e)}"
        )

@router.get("/monthly/{year}/{month}")
async def get_monthly_report(year: int, month: int):
    """Get monthly report"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        orders_collection = db.orders
        
        ist = tz.gettz('Asia/Kolkata')
        # Create date range for the month in IST
        start_of_month = datetime(year, month, 1, tzinfo=ist)
        if month == 12:
            end_of_month = datetime(year + 1, 1, 1, tzinfo=ist) - timedelta(days=1)
        else:
            end_of_month = datetime(year, month + 1, 1, tzinfo=ist) - timedelta(days=1)
        
        # Get estimates for the month
        estimates = await estimates_collection.find({
            "created_at": {
                "$gte": start_of_month,
                "$lte": end_of_month
            }
        }).to_list(length=None)
        
        # Get orders for the month
        orders = await orders_collection.find({
            "created_at": {
                "$gte": start_of_month,
                "$lte": end_of_month
            }
        }).to_list(length=None)
        
        # Calculate daily breakdown
        daily_estimates = {}
        daily_orders = {}
        
        for estimate in estimates:
            date_key = estimate["created_at"].strftime("%Y-%m-%d")
            if date_key not in daily_estimates:
                daily_estimates[date_key] = {"count": 0, "total": 0}
            daily_estimates[date_key]["count"] += 1
            daily_estimates[date_key]["total"] += estimate.get("total", 0)
        
        for order in orders:
            date_key = order["created_at"].strftime("%Y-%m-%d")
            if date_key not in daily_orders:
                daily_orders[date_key] = {"count": 0, "total": 0}
            daily_orders[date_key]["count"] += 1
            daily_orders[date_key]["total"] += order.get("total", 0)
        
        return {
            "period": {
                "year": year,
                "month": month,
                "start_date": start_of_month.isoformat(),
                "end_date": end_of_month.isoformat()
            },
            "summary": {
                "total_estimates": len(estimates),
                "total_orders": len(orders),
                "total_estimates_amount": sum(e.get("total", 0) for e in estimates),
                "total_orders_amount": sum(o.get("total", 0) for o in orders)
            },
            "daily_breakdown": {
                "estimates": daily_estimates,
                "orders": daily_orders
            }
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error generating monthly report: {str(e)}"
        )

@router.get("/staff-performance")
async def get_staff_performance_report():
    """Get staff performance report with separate order and estimate counts"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        orders_collection = db.orders
        
        # Get all estimates and orders
        estimates = await estimates_collection.find().to_list(length=None)
        orders = await orders_collection.find().to_list(length=None)
        
        # Group by staff member
        staff_performance = {}
        
        # Process estimates
        for estimate in estimates:
            staff_name = estimate.get("sale_by", "Unknown")
            if staff_name not in staff_performance:
                staff_performance[staff_name] = {
                    "estimates_count": 0,
                    "estimates_total": 0,
                    "orders_count": 0,
                    "orders_total": 0,
                    "total_transactions": 0,
                    "total_revenue": 0
                }
            
            staff_performance[staff_name]["estimates_count"] += 1
            staff_performance[staff_name]["estimates_total"] += estimate.get("total", 0)
            staff_performance[staff_name]["total_transactions"] += 1
            staff_performance[staff_name]["total_revenue"] += estimate.get("total", 0)
        
        # Process orders
        for order in orders:
            staff_name = order.get("sale_by", "Unknown")
            if staff_name not in staff_performance:
                staff_performance[staff_name] = {
                    "estimates_count": 0,
                    "estimates_total": 0,
                    "orders_count": 0,
                    "orders_total": 0,
                    "total_transactions": 0,
                    "total_revenue": 0
                }
            
            staff_performance[staff_name]["orders_count"] += 1
            staff_performance[staff_name]["orders_total"] += order.get("total", 0)
            staff_performance[staff_name]["total_transactions"] += 1
            staff_performance[staff_name]["total_revenue"] += order.get("total", 0)
        
        # Convert to list and sort by total revenue
        staff_list = [
            {
                "staff_name": name,
                **data
            }
            for name, data in staff_performance.items()
        ]
        staff_list.sort(key=lambda x: x["total_revenue"], reverse=True)
        
        return {
            "staff_performance": staff_list,
            "summary": {
                "total_staff": len(staff_list),
                "total_estimates": sum(s["estimates_count"] for s in staff_list),
                "total_orders": sum(s["orders_count"] for s in staff_list),
                "total_revenue": sum(s["total_revenue"] for s in staff_list)
            }
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error generating staff performance report: {str(e)}"
        )

@router.get("/estimates-only")
async def get_estimates_report():
    """Get estimates-only report"""
    try:
        db = get_database()
        estimates_collection = db.estimates
        
        # Get all estimates
        estimates = await estimates_collection.find().sort("created_at", -1).to_list(length=None)
        
        # Calculate statistics
        total_estimates = len(estimates)
        total_amount = sum(estimate.get("total", 0) for estimate in estimates)
        
        # Conversion breakdown
        conversion_counts = {
            "converted": 0,
            "pending": 0
        }
        for estimate in estimates:
            if estimate.get("is_converted_to_order", False):
                conversion_counts["converted"] += 1
            else:
                conversion_counts["pending"] += 1
        
        return {
            "estimates": {
                "total_count": total_estimates,
                "total_amount": total_amount,
                "conversion_breakdown": conversion_counts,
                "items": estimates
            }
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error generating estimates report: {str(e)}"
        )

@router.get("/orders-only")
async def get_orders_report():
    """Get orders-only report"""
    try:
        db = get_database()
        orders_collection = db.orders
        
        # Get all orders
        orders = await orders_collection.find().sort("created_at", -1).to_list(length=None)
        
        # Calculate statistics
        total_orders = len(orders)
        total_amount = sum(order.get("total", 0) for order in orders)
        
        # Payment mode breakdown
        payment_counts = {}
        for order in orders:
            payment_mode = order.get("payment_mode", "Cash")
            payment_counts[payment_mode] = payment_counts.get(payment_mode, 0) + 1
        
        return {
            "orders": {
                "total_count": total_orders,
                "total_amount": total_amount,
                "payment_breakdown": payment_counts,
                "items": orders
            }
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error generating orders report: {str(e)}"
        ) 