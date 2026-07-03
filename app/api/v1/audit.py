from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_audit_service, require_roles
from app.models.user import User
from app.schemas.audit import AuditActorOut, AuditLogListResponse, AuditLogOut
from app.services.audit_service import AuditService

router = APIRouter(prefix="/audit-logs", tags=["Audit Logs"])

_admin_only = require_roles("super_admin", "admin")


@router.get("/", response_model=AuditLogListResponse)
def list_audit_logs(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    user_id: Optional[int] = Query(None, description="Filter by actor user ID"),
    action: Optional[str] = Query(None, description="e.g. login, pdf_created, user_updated"),
    entity_type: Optional[str] = Query(None, description="auth | user | pdf"),
    from_date: Optional[datetime] = Query(None, description="Start of date range (ISO 8601)"),
    to_date: Optional[datetime] = Query(None, description="End of date range (ISO 8601)"),
    current_user: User = Depends(_admin_only),
    service: AuditService = Depends(get_audit_service),
):
    total, rows = service.list(skip, limit, user_id, action, entity_type, from_date, to_date)
    logs = [
        AuditLogOut(
            id=r["id"],
            actor=AuditActorOut(**r["actor"]),
            action=r["action"],
            entity_type=r["entity_type"],
            entity_id=r["entity_id"],
            details=r["details"],
            ip_address=r["ip_address"],
            status=r["status"],
            created_at=r["created_at"],
        )
        for r in rows
    ]
    return AuditLogListResponse(total=total, logs=logs)
