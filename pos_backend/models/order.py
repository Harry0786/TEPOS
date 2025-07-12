from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime

class OrderCreate(BaseModel):
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
    payment_mode: Optional[str] = "Cash"
    created_at: Optional[str] = None

class OrderResponse(BaseModel):
    id: str = Field(alias="_id")
    order_id: str
    sale_number: str
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
    payment_mode: str
    status: str = "Completed"
    created_at: datetime
    
    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True 