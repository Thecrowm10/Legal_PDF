from abc import ABC, abstractmethod
from datetime import datetime
from typing import Optional


class IAdminOtpRepository(ABC):

    @abstractmethod
    def create(self, user_id: int, otp_hash: str, expires_at: datetime) -> None:
        ...

    @abstractmethod
    def get_valid(self, user_id: int) -> Optional[dict]:
        ...

    @abstractmethod
    def mark_used(self, otp_id: int) -> None:
        ...
