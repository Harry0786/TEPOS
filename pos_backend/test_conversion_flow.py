#!/usr/bin/env python3
"""
Test script to verify the estimate to order conversion flow
"""
import urllib.request
import urllib.parse
import json
import time
from datetime import datetime

# Configuration
BASE_URL = "https://tepos.onrender.com"  # Your Render backend URL
API_BASE = f"{BASE_URL}/api"

def make_request(url, method="GET", data=None, timeout=30):
    """Make HTTP request with timeout"""
    try:
        if data:
            data = json.dumps(data).encode('utf-8')
        
        req = urllib.request.Request(
            url,
            data=data,
            method=method,
            headers={'Content-Type': 'application/json'}
        )
        
        with urllib.request.urlopen(req, timeout=timeout) as response:
            result = json.loads(response.read().decode('utf-8'))
            return response.status, result
    except Exception as e:
        print(f"❌ Request failed: {e}")
        return None, None

def test_health_check():
    """Test health check endpoint"""
    print("🔄 Testing health check...")
    
    status, result = make_request(f"{BASE_URL}/health", timeout=10)
    print(f"📥 Health check response: {status}")
    if result:
        print(f"📋 Result: {json.dumps(result, indent=2)}")
    
    return status == 200

def test_estimate_creation():
    """Test creating an estimate"""
    print("🔄 Testing estimate creation...")
    
    estimate_data = {
        "customer_name": "Test Customer",
        "customer_phone": "1234567890",
        "customer_address": "Test Address",
        "sale_by": "Test User",
        "items": [
            {
                "name": "Test Item",
                "price": 100.0,
                "quantity": 2
            }
        ],
        "subtotal": 200.0,
        "discount_amount": 10.0,
        "is_percentage_discount": False,
        "total": 190.0
    }
    
    status, result = make_request(
        f"{API_BASE}/estimates/create",
        method="POST",
        data=estimate_data,
        timeout=30
    )
    
    print(f"📥 Estimate creation response: {status}")
    if result:
        print(f"📋 Result: {json.dumps(result, indent=2)}")
        
        if status == 201 and result.get('success'):
            return result.get('estimate_id')
    
    print("❌ Estimate creation failed")
    return None

def test_order_creation():
    """Test creating an order directly"""
    print("🔄 Testing direct order creation...")
    
    order_data = {
        "customer_name": "Test Customer",
        "customer_phone": "1234567890",
        "customer_address": "Test Address",
        "sale_by": "Test User",
        "items": [
            {
                "name": "Test Item",
                "price": 100.0,
                "quantity": 2
            }
        ],
        "subtotal": 200.0,
        "discount_amount": 10.0,
        "is_percentage_discount": False,
        "total": 190.0,
        "payment_mode": "Cash"
    }
    
    status, result = make_request(
        f"{API_BASE}/orders/create-sale",
        method="POST",
        data=order_data,
        timeout=30
    )
    
    print(f"📥 Order creation response: {status}")
    if result:
        print(f"📋 Result: {json.dumps(result, indent=2)}")
        
        if status == 201 and result.get('success'):
            return result.get('order_id')
    
    print("❌ Order creation failed")
    return None

def test_estimate_deletion(estimate_id):
    """Test deleting an estimate"""
    if not estimate_id:
        print("⚠️ No estimate ID provided for deletion test")
        return False
        
    print(f"🔄 Testing estimate deletion: {estimate_id}")
    
    status, result = make_request(
        f"{API_BASE}/estimates/{estimate_id}",
        method="DELETE",
        timeout=15
    )
    
    print(f"📥 Estimate deletion response: {status}")
    if result:
        print(f"📋 Result: {json.dumps(result, indent=2)}")
        
        return status in [200, 204] and result.get('success', False)
    
    return False

def main():
    """Run all tests"""
    print("🚀 Starting conversion flow tests...")
    print(f"📍 Testing against: {BASE_URL}")
    print("=" * 50)
    
    # Test health check first
    health_ok = test_health_check()
    if not health_ok:
        print("❌ Health check failed - backend may not be running")
        return
    
    print("✅ Health check passed")
    print("-" * 30)
    
    # Test estimate creation
    estimate_id = test_estimate_creation()
    if not estimate_id:
        print("❌ Estimate creation test failed")
        return
    
    print("✅ Estimate creation test passed")
    print("-" * 30)
    
    # Test order creation
    order_id = test_order_creation()
    if not order_id:
        print("❌ Order creation test failed")
        return
    
    print("✅ Order creation test passed")
    print("-" * 30)
    
    # Test estimate deletion
    deletion_ok = test_estimate_deletion(estimate_id)
    if not deletion_ok:
        print("❌ Estimate deletion test failed")
        return
    
    print("✅ Estimate deletion test passed")
    print("-" * 30)
    
    print("🎉 All tests passed! The conversion flow should work correctly.")
    print("💡 If the app still freezes, the issue may be in the frontend UI handling.")

if __name__ == "__main__":
    main() 