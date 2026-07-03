import json
import logging
from datetime import datetime
from typing import Optional

from app.interfaces.audit_log_repository import IAuditLogRepository

logger = logging.getLogger(__name__)


class AuditService:

    def __init__(self, repo: IAuditLogRepository):
        self._repo = repo

    def log(
        self,
        action: str,
        entity_type: str,
        actor_user_id: Optional[int] = None,
        entity_id: Optional[int] = None,
        details: Optional[dict] = None,
        ip_address: Optional[str] = None,
        status: str = "success",
    ) -> None:
        try:
            self._repo.create(
                user_id=actor_user_id,
                action=action,
                entity_type=entity_type,
                entity_id=entity_id,
                details=json.dumps(details, default=str) if details else None,
                ip_address=ip_address,
                status=status,
            )
        except Exception as exc:
            logger.warning("[AuditService] Failed to write log action=%s: %s", action, exc)

    def list(
        self,
        skip: int = 0,
        limit: int = 20,
        user_id: Optional[int] = None,
        action: Optional[str] = None,
        entity_type: Optional[str] = None,
        from_date: Optional[datetime] = None,
        to_date: Optional[datetime] = None,
        exclude_user_id: Optional[int] = None,
    ) -> tuple[int, list[dict]]:
        return self._repo.list(skip, limit, user_id, action, entity_type, from_date, to_date, exclude_user_id)
