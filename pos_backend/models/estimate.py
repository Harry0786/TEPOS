from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime

class EstimateCreate(BaseModel):
    customer_name: str
    customer_phone: str
    customer_address: str
    sale_by: str  # Added field for tracking who made the sale
    items: List[Dict[str, Any]]  # Changed to match Flutter app structure: [{"id": 123, "name": "Product", "price": 100, "quantity": 2}]
    subtotal: float
    discount_amount: float
    is_percentage_discount: bool
    discount_percentage: Optional[float] = None
    total: float
    created_at: Optional[str] = None

class EstimateResponse(BaseModel):
    id: str = Field(alias="_id")
    estimate_id: str
    estimate_number: str  # Sequential estimate number (e.g., #001)
    customer_name: str
    customer_phone: str
    customer_address: str
    sale_by: str
    items: List[Dict[str, Any]]
    subtotal: float
    discount_amount: float
    is_percentage_discount: bool
    discount_percentage: Optional[float] = None
    total: float
    created_at: datetime
    
    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True