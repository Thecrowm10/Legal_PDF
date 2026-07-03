import hashlib
import random
from datetime import datetime, timedelta, timezone
from typing import Optional

from app.core.security import build_user_token
from app.interfaces.admin_otp_repository import IAdminOtpRepository
from app.interfaces.user_repository import IUserRepository
from app.services.sms_service import SmsService

_OTP_TTL_MINUTES = 10
_ADMIN_ROLES = {"super_admin", "admin"}


class AdminAuthService:

    def __init__(
        self,
        user_repo: IUserRepository,
        otp_repo: IAdminOtpRepository,
        sms_svc: SmsService,
    ):
        self._user_repo = user_repo
        self._otp_repo  = otp_repo
        self._sms_svc   = sms_svc

    @staticmethod
    def _generate_otp() -> str:
        return str(random.randint(100000, 999999))

    @staticmethod
    def _hash_otp(otp: str) -> str:
        return hashlib.sha256(otp.encode()).hexdigest()

    def request_otp(self, mobile_number: str) -> None:
        """
        Generate and send a login OTP to the given mobile number.
        Raises ValueError if the number is not linked to an active admin account.
        """
        user = self._user_repo.get_by_mobile(mobile_number.strip())
        if not user or not user.is_active:
            raise ValueError("No active account found with this mobile number.")
        if not user.role or user.role.name not in _ADMIN_ROLES:
            raise ValueError("This login method is only available for administrators.")

        otp = self._generate_otp()
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=_OTP_TTL_MINUTES)
        self._otp_repo.create(user.id, self._hash_otp(otp), expires_at)
        self._sms_svc.send_admin_login_otp(mobile_number, otp)

    def verify_otp(self, mobile_number: str, otp: str) -> Optional[str]:
        """
        Verify the OTP and return a JWT on success, or None on failure.
        """
        user = self._user_repo.get_by_mobile(mobile_number.strip())
        if not user or not user.is_active:
            return None
        if not user.role or user.role.name not in _ADMIN_ROLES:
            return None

        record = self._otp_repo.get_valid(user.id)
        if not record:
            return None
        if record["otp_hash"] != self._hash_otp(otp):
            return None

        self._otp_repo.mark_used(record["id"])
        fresh_user = self._user_repo.get_by_id(user.id)
        return build_user_token(fresh_user)
