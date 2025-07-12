#!/usr/bin/env python3
"""
Test script for WebSocket functionality
Run this to test if WebSocket connections and broadcasts are working
"""

import asyncio
import websockets
import requests
import json
import time

async def test_websocket():
    """Test WebSocket connection and message reception"""
    uri = "ws://localhost:8000/ws"
    
    print("🔌 Connecting to WebSocket...")
    try:
        async with websockets.connect(uri) as websocket:
            print("✅ Connected to WebSocket")
            
            # Send a test message
            await websocket.send("Hello from test client")
            print("📤 Sent test message")
            
            # Wait for any incoming messages
            print("📥 Waiting for messages...")
            try:
                message = await asyncio.wait_for(websocket.recv(), timeout=10.0)
                print(f"📨 Received message: {message}")
            except asyncio.TimeoutError:
                print("⏰ No messages received within 10 seconds")
                
    except Exception as e:
        print(f"❌ WebSocket connection failed: {e}")

def test_broadcast():
    """Test broadcast by creating a new estimate"""
    print("\n🧪 Testing broadcast by creating a new estimate...")
    
    url = "http://localhost:8000/api/estimates/create"
    data = {
        "customer_name": "WebSocket Test Customer",
        "customer_phone": "1234567890",
        "customer_address": "Test Address",
        "sale_by": "Test User",
        "items": [
            {
                "id": 999999,
                "name": "WebSocket Test Item",
                "price": 100.0,
                "quantity": 1
            }
        ],
        "subtotal": 100.0,
        "discount_amount": 0.0,
        "is_percentage_discount": False,
        "total": 100.0
    }
    
    try:
        response = requests.post(url, json=data)
        if response.status_code == 201:
            print("✅ Estimate created successfully")
            result = response.json()
            print(f"📋 Estimate Number: {result.get('estimate_number', 'N/A')}")
        else:
            print(f"❌ Failed to create estimate: {response.status_code}")
            print(response.text)
    except Exception as e:
        print(f"❌ Error creating estimate: {e}")

async def main():
    """Main test function"""
    print("🚀 Starting WebSocket Tests")
    print("=" * 50)
    
    # Test 1: WebSocket connection
    await test_websocket()
    
    # Test 2: Broadcast functionality
    test_broadcast()
    
    print("\n" + "=" * 50)
    print("🏁 WebSocket tests completed")

if __name__ == "__main__":
    asyncio.run(main()) 