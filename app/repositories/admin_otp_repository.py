from datetime import datetime
from typing import Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.interfaces.admin_otp_repository import IAdminOtpRepository


class AdminOtpRepository(IAdminOtpRepository):

    def __init__(self, db: Session):
        self._db = db

    def create(self, user_id: int, otp_hash: str, expires_at: datetime) -> None:
        self._db.execute(
            text(
                "EXEC sp_create_admin_login_otp "
                "@user_id = :user_id, @otp_hash = :otp_hash, "
                "@expires_at = :expires_at"
            ),
            {"user_id": user_id, "otp_hash": otp_hash, "expires_at": expires_at},
        )
        self._db.commit()

    def get_valid(self, user_id: int) -> Optional[dict]:
        result = self._db.execute(
            text("EXEC sp_get_valid_admin_login_otp @user_id = :user_id"),
            {"user_id": user_id},
        )
        row = result.mappings().fetchone()
        return dict(row) if row else None

    def mark_used(self, otp_id: int) -> None:
        self._db.execute(
            text("EXEC sp_mark_admin_login_otp_used @otp_id = :otp_id"),
            {"otp_id": otp_id},
        )
        self._db.commit()
