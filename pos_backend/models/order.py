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
    amount_paid: Optional[float] = None  # Amount actually paid by customer (can be less than total)
    payment_mode: Optional[str] = "Cash"
    created_at: Optional[str] = None
    source_estimate_id: Optional[str] = None  # If order was created from estimate
    source_estimate_number: Optional[str] = None  # Estimate number if created from estimate

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
    amount_paid: Optional[float] = None  # Amount actually paid by customer (can be less than total)
    payment_mode: str
    status: str = "Completed"
    created_at: datetime
    source_estimate_id: Optional[str] = None  # If order was created from estimate
    source_estimate_number: Optional[str] = None  # Estimate number if created from estimate
    is_from_estimate: bool = False  # Whether order was created from estimate
    
    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True 