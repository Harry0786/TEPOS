#!/usr/bin/env python3
"""
Test script to verify the updated payment breakdown functionality
in the today's report endpoint.
"""

import requests
import json
from datetime import datetime
import time

# Configuration
BASE_URL = "https://pos-backend-8j8k.onrender.com"  # Update with your actual backend URL
# BASE_URL = "http://localhost:8000"  # For local testing

def test_today_report_payment_breakdown():
    """Test the today's report endpoint with payment breakdown"""
    print("🧪 Testing Today's Report Payment Breakdown...")
    
    try:
        # Test the today's report endpoint
        response = requests.get(f"{BASE_URL}/reports/today", timeout=30)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Successfully fetched today's report")
            
            # Check if payment breakdown exists
            if 'orders' in data and 'payment_breakdown' in data['orders']:
                payment_breakdown = data['orders']['payment_breakdown']
                print(f"📊 Payment breakdown structure: {json.dumps(payment_breakdown, indent=2)}")
                
                # Check if all expected payment modes are present
                expected_modes = ['cash', 'card', 'online', 'upi', 'bank_transfer', 'cheque', 'other']
                for mode in expected_modes:
                    if mode in payment_breakdown:
                        mode_data = payment_breakdown[mode]
                        if 'count' in mode_data and 'amount' in mode_data:
                            print(f"✅ {mode}: {mode_data['count']} orders, Rs. {mode_data['amount']:.2f}")
                        else:
                            print(f"❌ {mode}: Missing count or amount fields")
                    else:
                        print(f"❌ {mode}: Missing from payment breakdown")
                
                # Show summary
                total_orders = data['orders']['count']
                total_amount = data['orders']['total_amount']
                print(f"\n📈 Summary:")
                print(f"   Total Orders: {total_orders}")
                print(f"   Total Amount: Rs. {total_amount:.2f}")
                
                # Calculate total from breakdown
                breakdown_total = sum(mode_data['amount'] for mode_data in payment_breakdown.values())
                breakdown_count = sum(mode_data['count'] for mode_data in payment_breakdown.values())
                print(f"   Breakdown Total: Rs. {breakdown_total:.2f}")
                print(f"   Breakdown Count: {breakdown_count}")
                
                if abs(total_amount - breakdown_total) < 0.01:
                    print("✅ Payment breakdown totals match")
                else:
                    print(f"⚠️ Payment breakdown totals don't match: {total_amount} vs {breakdown_total}")
                
            else:
                print("❌ Payment breakdown not found in response")
                print(f"Response structure: {list(data.keys())}")
                if 'orders' in data:
                    print(f"Orders structure: {list(data['orders'].keys())}")
                
        else:
            print(f"❌ Failed to fetch today's report: {response.status_code}")
            print(f"Response: {response.text}")
            
    except requests.exceptions.Timeout:
        print("❌ Request timed out")
    except requests.exceptions.ConnectionError:
        print("❌ Connection error - check if backend is running")
    except Exception as e:
        print(f"❌ Error: {e}")

def test_sample_data():
    """Test with sample order data to verify payment breakdown calculation"""
    print("\n🧪 Testing with sample data...")
    
    # Sample orders with different payment modes
    sample_orders = [
        {"payment_mode": "Cash", "total": 1000.0, "status": "completed"},
        {"payment_mode": "Card", "total": 2500.0, "status": "completed"},
        {"payment_mode": "UPI", "total": 750.0, "status": "completed"},
        {"payment_mode": "Online", "total": 1500.0, "status": "completed"},
        {"payment_mode": "Cash", "total": 800.0, "status": "completed"},
        {"payment_mode": "Bank Transfer", "total": 3000.0, "status": "completed"},
        {"payment_mode": "Cheque", "total": 1200.0, "status": "completed"},
        {"payment_mode": "Other", "total": 500.0, "status": "completed"},
    ]
    
    # Simulate the backend calculation
    payment_breakdown = {
        "cash": {"count": 0, "amount": 0.0},
        "card": {"count": 0, "amount": 0.0},
        "online": {"count": 0, "amount": 0.0},
        "upi": {"count": 0, "amount": 0.0},
        "bank_transfer": {"count": 0, "amount": 0.0},
        "cheque": {"count": 0, "amount": 0.0},
        "other": {"count": 0, "amount": 0.0}
    }
    
    for order in sample_orders:
        payment_mode = order.get("payment_mode", "").lower()
        amount = order.get("total", 0)
        
        if payment_mode in payment_breakdown:
            payment_breakdown[payment_mode]["count"] += 1
            payment_breakdown[payment_mode]["amount"] += amount
        else:
            payment_breakdown["other"]["count"] += 1
            payment_breakdown["other"]["amount"] += amount
    
    print("📊 Sample payment breakdown calculation:")
    for mode, data in payment_breakdown.items():
        if data['count'] > 0:
            print(f"   {mode}: {data['count']} orders, Rs. {data['amount']:.2f}")
    
    total_amount = sum(data['amount'] for data in payment_breakdown.values())
    total_count = sum(data['count'] for data in payment_breakdown.values())
    print(f"\n📈 Sample totals: {total_count} orders, Rs. {total_amount:.2f}")

if __name__ == "__main__":
    print("🚀 Payment Breakdown Test Script")
    print("=" * 50)
    
    # Test with sample data first
    test_sample_data()
    
    print("\n" + "=" * 50)
    
    # Test the actual endpoint
    test_today_report_payment_breakdown()
    
    print("\n✅ Test completed!") 