import json
from datetime import datetime
from typing import Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.interfaces.audit_log_repository import IAuditLogRepository


class AuditLogRepository(IAuditLogRepository):

    def __init__(self, db: Session):
        self._db = db

    def create(
        self,
        user_id: Optional[int],
        action: str,
        entity_type: str,
        entity_id: Optional[int] = None,
        details: Optional[str] = None,
        ip_address: Optional[str] = None,
        status: str = "success",
    ) -> None:
        self._db.execute(
            text(
                "EXEC sp_create_audit_log "
                "@user_id = :user_id, @action = :action, "
                "@entity_type = :entity_type, @entity_id = :entity_id, "
                "@details = :details, @ip_address = :ip_address, "
                "@status = :status"
            ),
            {
                "user_id": user_id,
                "action": action,
                "entity_type": entity_type,
                "entity_id": entity_id,
                "details": details,
                "ip_address": ip_address,
                "status": status,
            },
        )
        self._db.commit()

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
        result = self._db.execute(
            text(
                "EXEC sp_list_audit_logs "
                "@skip = :skip, @limit = :limit, "
                "@user_id = :user_id, @action = :action, "
                "@entity_type = :entity_type, @from_date = :from_date, "
                "@to_date = :to_date, @exclude_user_id = :exclude_user_id"
            ),
            {
                "skip": skip,
                "limit": limit,
                "user_id": user_id,
                "action": action,
                "entity_type": entity_type,
                "from_date": from_date,
                "to_date": to_date,
                "exclude_user_id": exclude_user_id,
            },
        )
        rows = result.mappings().fetchall()
        if not rows:
            return 0, []
        total = rows[0]["total"]
        return total, [self._map_row(r) for r in rows]

    @staticmethod
    def _map_row(row) -> dict:
        d = dict(row)
        raw = d.get("details")
        try:
            details = json.loads(raw) if raw else None
        except (json.JSONDecodeError, TypeError):
            details = {"raw": raw}
        return {
            "id": d["id"],
            "actor": {
                "id": d.get("user_id"),
                "username": d.get("actor_username"),
                "first_name": d.get("actor_first_name"),
                "last_name": d.get("actor_last_name"),
            },
            "action": d["action"],
            "entity_type": d["entity_type"],
            "entity_id": d.get("entity_id"),
            "details": details,
            "ip_address": d.get("ip_address"),
            "status": d["status"],
            "created_at": d["created_at"],
        }
