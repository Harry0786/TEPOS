#!/usr/bin/env python3
"""
Test script for estimate-to-order conversion endpoint
"""

import requests
import json
import time
from datetime import datetime

# Configuration
BASE_URL = "https://pos-2wc9.onrender.com/api"
TIMEOUT = 30

def test_conversion_endpoint():
    """Test the estimate-to-order conversion endpoint"""
    print("🚀 Testing estimate-to-order conversion endpoint...")
    print(f"📍 Testing against: {BASE_URL}")
    print("=" * 50)
    
    # Step 1: Create an estimate
    print("🔄 Step 1: Creating test estimate...")
    estimate_data = {
        "customer_name": "Conversion Test Customer",
        "customer_phone": "9876543210",
        "customer_address": "Test Address",
        "sale_by": "Test User",
        "items": [
            {
                "name": "Test Item 1",
                "price": 100.0,
                "quantity": 2
            },
            {
                "name": "Test Item 2", 
                "price": 50.0,
                "quantity": 1
            }
        ],
        "subtotal": 250.0,
        "discount_amount": 25.0,
        "is_percentage_discount": False,
        "total": 225.0
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/estimates/create",
            json=estimate_data,
            timeout=TIMEOUT
        )
        print(f"📥 Estimate creation response: {response.status_code}")
        
        if response.status_code == 201:
            estimate_result = response.json()
            print(f"📋 Estimate created: {json.dumps(estimate_result, indent=2)}")
            estimate_id = estimate_result.get('estimate_id')
            estimate_number = estimate_result.get('estimate_number')
            print(f"✅ Estimate created successfully: {estimate_id} ({estimate_number})")
        else:
            print(f"❌ Failed to create estimate: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error creating estimate: {e}")
        return False
    
    print("-" * 30)
    
    # Step 2: Convert estimate to order
    print("🔄 Step 2: Converting estimate to order...")
    conversion_params = {
        "payment_mode": "Cash",
        "sale_by": "Test User"
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/estimates/{estimate_id}/convert-to-order",
            params=conversion_params,
            timeout=TIMEOUT
        )
        print(f"📥 Conversion response: {response.status_code}")
        print(f"📥 Response body: {response.text}")
        
        if response.status_code == 200:
            conversion_result = response.json()
            print(f"📋 Conversion result: {json.dumps(conversion_result, indent=2)}")
            
            if conversion_result.get('success'):
                order_id = conversion_result.get('order_id')
                sale_number = conversion_result.get('sale_number')
                print(f"✅ Estimate converted successfully!")
                print(f"   Order ID: {order_id}")
                print(f"   Sale Number: {sale_number}")
                print(f"   Original Estimate: {estimate_id} ({estimate_number})")
            else:
                print(f"❌ Conversion failed: {conversion_result.get('message')}")
                return False
        else:
            print(f"❌ Conversion request failed: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error converting estimate: {e}")
        return False
    
    print("-" * 30)
    
    # Step 3: Verify the estimate is marked as converted
    print("🔄 Step 3: Verifying estimate conversion status...")
    try:
        response = requests.get(
            f"{BASE_URL}/estimates/{estimate_id}",
            timeout=TIMEOUT
        )
        print(f"📥 Estimate status response: {response.status_code}")
        
        if response.status_code == 200:
            estimate_status = response.json()
            print(f"📋 Estimate status: {json.dumps(estimate_status, indent=2)}")
            
            is_converted = estimate_status.get('is_converted_to_order', False)
            linked_order_id = estimate_status.get('linked_order_id')
            linked_order_number = estimate_status.get('linked_order_number')
            
            if is_converted:
                print(f"✅ Estimate correctly marked as converted")
                print(f"   Linked Order ID: {linked_order_id}")
                print(f"   Linked Order Number: {linked_order_number}")
            else:
                print(f"❌ Estimate not marked as converted")
                return False
        else:
            print(f"❌ Failed to get estimate status: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error checking estimate status: {e}")
        return False
    
    print("-" * 30)
    
    # Step 4: Verify the order exists
    print("🔄 Step 4: Verifying order exists...")
    try:
        response = requests.get(
            f"{BASE_URL}/orders/orders-only",
            timeout=TIMEOUT
        )
        print(f"📥 Orders response: {response.status_code}")
        
        if response.status_code == 200:
            orders_result = response.json()
            orders = orders_result.get('orders', {}).get('items', [])
            
            # Find our converted order
            converted_order = None
            for order in orders:
                if order.get('order_id') == conversion_result.get('order_id'):
                    converted_order = order
                    break
            
            if converted_order:
                print(f"✅ Converted order found in orders list")
                print(f"   Order ID: {converted_order.get('order_id')}")
                print(f"   Sale Number: {converted_order.get('sale_number')}")
                print(f"   Customer: {converted_order.get('customer_name')}")
                print(f"   Total: {converted_order.get('total')}")
                print(f"   Source Estimate: {converted_order.get('source_estimate_id')}")
            else:
                print(f"❌ Converted order not found in orders list")
                return False
        else:
            print(f"❌ Failed to get orders: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error checking orders: {e}")
        return False
    
    print("=" * 50)
    print("🎉 All conversion tests passed!")
    print("💡 The conversion endpoint is working correctly.")
    return True

if __name__ == "__main__":
    success = test_conversion_endpoint()
    if not success:
        print("❌ Conversion tests failed!")
        exit(1) 