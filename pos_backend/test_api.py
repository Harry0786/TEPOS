import requests
import json

# Base URL for the API
BASE_URL = "http://127.0.0.1:8000/api"

def test_create_estimate():
    """Test estimate creation endpoint"""
    url = f"{BASE_URL}/estimates/create"
    data = {
        "customer_name": "John Doe",
        "customer_phone": "9876543210",
        "customer_address": "123 Main Street, City, State",
        "sale_by": "Rajesh Goyal",
        "items": [
            {
                "id": 123456789,
                "name": "LED Bulb",
                "price": 150.0,
                "quantity": 2
            },
            {
                "id": 987654321,
                "name": "Switch Board",
                "price": 200.0,
                "quantity": 1
            }
        ],
        "subtotal": 500.0,
        "discount_amount": 50.0,
        "is_percentage_discount": False,
        "total": 450.0
    }
    
    try:
        response = requests.post(url, json=data)
        print(f"Create Estimate Response Status: {response.status_code}")
        print(f"Create Estimate Response: {json.dumps(response.json(), indent=2)}")
        
        # Test getting estimate by number if creation was successful
        if response.status_code == 201:
            response_data = response.json()
            if response_data.get('estimate_number'):
                estimate_number = response_data['estimate_number']
                print(f"\nTesting get estimate by number: {estimate_number}")
                get_url = f"{BASE_URL}/estimates/number/{estimate_number}"
                get_response = requests.get(get_url)
                print(f"Get Estimate by Number Response Status: {get_response.status_code}")
                print(f"Get Estimate by Number Response: {json.dumps(get_response.json(), indent=2)}")
        
        return response.json()
    except Exception as e:
        print(f"Create Estimate Error: {e}")

def test_get_estimates():
    """Test get all estimates endpoint"""
    url = f"{BASE_URL}/estimates/"
    
    try:
        response = requests.get(url)
        print(f"Get Estimates Response Status: {response.status_code}")
        print(f"Get Estimates Response: {json.dumps(response.json(), indent=2)}")
        return response.json()
    except Exception as e:
        print(f"Get Estimates Error: {e}")

if __name__ == "__main__":
    print("Testing POS Backend API Endpoints")
    print("=" * 50)
    
    print("\n1. Testing Create Estimate:")
    test_create_estimate()
    
    print("\n2. Testing Get Estimates:")
    test_get_estimates()
    
    print("\nAPI Testing Complete!") 