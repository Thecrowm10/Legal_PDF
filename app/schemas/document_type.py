from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class DocumentTypeOut(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    is_active: bool = True
    created_at: datetime

    model_config = {"from_attributes": True}


class DocumentTypeCreate(BaseModel):
    name: str
    description: Optional[str] = None
