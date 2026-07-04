from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_audit_service, require_roles
from app.models.user import User
from app.schemas.audit import AuditActorOut, AuditLogListResponse, AuditLogOut
from app.services.audit_service import AuditService

router = APIRouter(prefix="/audit-logs", tags=["Audit Logs"])

_audit_roles = require_roles("super Admin", "admin", "nodal Officer")


@router.get("/", response_model=AuditLogListResponse)
def list_audit_logs(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    user_id: Optional[int] = Query(None, description="Filter by actor user ID"),
    action: Optional[str] = Query(None, description="e.g. login, pdf_created, user_updated"),
    entity_type: Optional[str] = Query(None, description="auth | user | pdf"),
    from_date: Optional[datetime] = Query(None, description="Start of date range (ISO 8601)"),
    to_date: Optional[datetime] = Query(None, description="End of date range (ISO 8601)"),
    current_user: User = Depends(_audit_roles),
    service: AuditService = Depends(get_audit_service),
):
    # Nodal officers are automatically scoped to their designated departments
    dept_ids = None
    role_name = current_user.role.name if current_user.role else None
    if role_name == "nodal Officer" and current_user.department_id:
        dept_ids = current_user.department_id  # comma-separated, e.g. "1,3,7"

    total, rows = service.list(
        skip, limit, user_id, action, entity_type, from_date, to_date,
        exclude_user_id=current_user.id,
        department_ids=dept_ids,
    )
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
