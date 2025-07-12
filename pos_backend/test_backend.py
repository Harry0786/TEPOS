import requests
import json

def test_backend():
    try:
        # Test basic API endpoint
        response = requests.get('http://localhost:8000/api/')
        print(f"API Root Status: {response.status_code}")
        print(f"API Root Response: {response.json()}")
        
        # Test orders endpoint
        response = requests.get('http://localhost:8000/api/orders/all')
        print(f"Orders Status: {response.status_code}")
        print(f"Orders Response: {response.json()}")
        
        # Test create-sale endpoint with sample data
        sample_data = {
            "customer_name": "Test Customer",
            "customer_phone": "1234567890",
            "customer_address": "Test Address",
            "sale_by": "Rajesh Goyal",
            "items": [{"id": 1, "name": "Test Product", "price": 100, "quantity": 1}],
            "subtotal": 100,
            "discount_amount": 0,
            "is_percentage_discount": True,
            "total": 100
        }
        
        response = requests.post(
            'http://localhost:8000/api/orders/create-sale',
            headers={'Content-Type': 'application/json'},
            data=json.dumps(sample_data)
        )
        print(f"Create Sale Status: {response.status_code}")
        print(f"Create Sale Response: {response.text}")
        
    except requests.exceptions.ConnectionError:
        print("Error: Could not connect to backend. Is the server running?")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_backend() 