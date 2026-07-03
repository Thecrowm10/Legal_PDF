from abc import ABC, abstractmethod
from datetime import datetime
from typing import Optional


class IAuditLogRepository(ABC):

    @abstractmethod
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
        ...

    @abstractmethod
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
        ...
