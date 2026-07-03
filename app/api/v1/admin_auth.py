import logging

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.dependencies import get_admin_auth_service
from app.schemas.auth import AdminOtpRequest, AdminOtpVerifyRequest, TokenResponse
from app.services.admin_auth_service import AdminAuthService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin/auth", tags=["Admin Authentication"])


@router.post("/request-otp", status_code=status.HTTP_200_OK)
def request_admin_otp(
    body: AdminOtpRequest,
    service: AdminAuthService = Depends(get_admin_auth_service),
):
    try:
        service.request_otp(body.mobile_number)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    except Exception as exc:
        logger.exception("[admin/request-otp] Unexpected error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Could not send OTP. Please try again later.",
        )
    return {"message": "OTP sent to your registered mobile number. Valid for 10 minutes."}


@router.post("/verify-otp", response_model=TokenResponse)
def verify_admin_otp(
    body: AdminOtpVerifyRequest,
    service: AdminAuthService = Depends(get_admin_auth_service),
):
    token = service.verify_otp(body.mobile_number, body.otp)
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired OTP.",
        )
    return TokenResponse(access_token=token)
