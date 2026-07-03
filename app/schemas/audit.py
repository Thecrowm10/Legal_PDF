from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel


class AuditActorOut(BaseModel):
    id: Optional[int] = None
    username: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None


class AuditLogOut(BaseModel):
    id: int
    actor: AuditActorOut
    action: str
    entity_type: str
    entity_id: Optional[int] = None
    details: Optional[dict[str, Any]] = None
    ip_address: Optional[str] = None
    status: str
    created_at: datetime


class AuditLogListResponse(BaseModel):
    total: int
    logs: list[AuditLogOut]
