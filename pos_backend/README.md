# POS Backend API

A FastAPI-based backend for the Point of Sale (POS) system that handles estimate management.

## Features

- Estimate creation and management
- MongoDB database integration
- RESTful API endpoints
- CORS support for Flutter app

## API Endpoints

### Estimates

#### POST `/api/estimates/create`
Create a new estimate.

**Request Body:**
```json
{
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
    }
  ],
  "subtotal": 300.0,
  "discount_amount": 30.0,
  "is_percentage_discount": true,
  "total": 270.0
}
```

**Response:**
```json
{
  "success": true,
  "message": "Estimate sent successfully!",
  "data": {
    "estimate_id": "EST-ABC12345",
    "estimate_number": "#001",
    "customer_name": "John Doe",
    "total": 270.0,
    "created_at": "2024-01-01T12:00:00"
  },
  "estimate_id": "EST-ABC12345",
  "estimate_number": "#001"
}
```

#### GET `/api/estimates/`
Get all estimates (sorted by estimate number).

#### GET `/api/estimates/{estimate_id}`
Get a specific estimate by ID.

#### GET `/api/estimates/number/{estimate_number}`
Get a specific estimate by estimate number (e.g., #001, #002).

## Setup Instructions

### Prerequisites

- Python 3.8+
- MongoDB (local or cloud)
- pip

### Installation

1. Clone the repository and navigate to the backend directory:
```bash
cd pos_backend
```

2. Create a virtual environment:
```bash
python -m venv venv
```

3. Activate the virtual environment:
```bash
# Windows
venv\Scripts\activate

# macOS/Linux
source venv/bin/activate
```

4. Install dependencies:
```bash
pip install -r requirements.txt
```

5. Create a `.env` file with your MongoDB configuration:
```env
MONGODB_URL=mongodb://localhost:27017
DATABASE_NAME=pos_db
```

6. Start the server:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at `http://127.0.0.1:8000`

### Testing

Run the test script to verify all endpoints:
```bash
python test_api.py
```

## Database Schema

### Estimates Collection
```json
{
  "_id": "ObjectId",
  "estimate_id": "EST-ABC12345",
  "estimate_number": "#001",
  "customer_name": "John Doe",
  "customer_phone": "9876543210",
  "customer_address": "123 Main Street",
  "sale_by": "Rajesh Goyal",
  "items": [
    {
      "id": 123456789,
      "name": "LED Bulb",
      "price": 150.0,
      "quantity": 2
    }
  ],
  "subtotal": 300.0,
  "discount_amount": 30.0,
  "is_percentage_discount": true,
  "discount_percentage": 10.0,
  "total": 270.0,
  "created_at": "2024-01-01T12:00:00"
}
```

## Flutter Integration

The backend is designed to work with the Flutter POS app. The API endpoints match the expected format in `api_service.dart`:

- Base URL: `http://127.0.0.1:8000/api`
- Estimate endpoints: `/estimates/create`

## Error Handling

All endpoints return consistent error responses:

```json
{
  "detail": "Error message description"
}
```

Common HTTP status codes:
- 200: Success
- 201: Created
- 400: Bad Request
- 404: Not Found
- 500: Internal Server Error

## Development

To run in development mode with auto-reload:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

To access the interactive API documentation:
- Swagger UI: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc` 