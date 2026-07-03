import logging

from app.core.config import settings

logger = logging.getLogger(__name__)


class SmsService:

    def send_admin_login_otp(self, to_number: str, otp: str) -> None:
        self._send(
            to_number,
            f"Your admin login OTP is: {otp}. Valid for 10 minutes. Do not share this with anyone.",
        )

    def send_otp(self, to_number: str, otp: str) -> None:
        self._send(
            to_number,
            f"Your Haryana Legal Knowledge System password reset OTP is: {otp}. Valid for 10 minutes.",
        )

    def _send(self, to_number: str, body: str) -> None:
        if not settings.TWILIO_ACCOUNT_SID or not settings.TWILIO_AUTH_TOKEN:
            logger.warning("[SmsService] Twilio not configured — message to %s: %s", to_number, body)
            return

        try:
            from twilio.rest import Client  # imported lazily so missing package doesn't crash startup
            client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
            client.messages.create(
                body=body,
                from_=settings.TWILIO_PHONE_NUMBER,
                to=to_number,
            )
            logger.info("[SmsService] SMS sent to %s", to_number)
        except ImportError:
            logger.error("[SmsService] twilio package not installed. Run: pip install twilio")
            raise RuntimeError("SMS service unavailable — twilio package missing")
        except Exception as exc:
            logger.error("[SmsService] Failed to send SMS to %s: %s", to_number, exc)
            raise
