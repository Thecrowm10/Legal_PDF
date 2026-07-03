import logging

from fastapi import APIRouter, Depends, HTTPException, Request, status

from app.core.dependencies import get_admin_auth_service, get_audit_service
from app.core.security import decode_access_token
from app.schemas.auth import AdminOtpRequest, AdminOtpVerifyRequest, TokenResponse
from app.services.admin_auth_service import AdminAuthService
from app.services.audit_service import AuditService
from app.utils.request_utils import get_client_ip

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin/auth", tags=["Admin Authentication"])


@router.post("/request-otp", status_code=status.HTTP_200_OK)
def request_admin_otp(
    body: AdminOtpRequest,
    request: Request,
    service: AdminAuthService = Depends(get_admin_auth_service),
    audit: AuditService = Depends(get_audit_service),
):
    ip = get_client_ip(request)
    try:
        service.request_otp(body.mobile_number)
    except ValueError as exc:
        audit.log(
            "admin_otp_request_failed", "auth",
            details={"mobile": body.mobile_number, "error": str(exc)},
            ip_address=ip,
            status="failure",
        )
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    except Exception as exc:
        logger.exception("[admin/request-otp] Unexpected error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Could not send OTP. Please try again later.",
        )
    audit.log("admin_otp_requested", "auth", details={"mobile": body.mobile_number}, ip_address=ip)
    return {"message": "OTP sent to your registered mobile number. Valid for 10 minutes."}


@router.post("/verify-otp", response_model=TokenResponse)
def verify_admin_otp(
    body: AdminOtpVerifyRequest,
    request: Request,
    service: AdminAuthService = Depends(get_admin_auth_service),
    audit: AuditService = Depends(get_audit_service),
):
    ip = get_client_ip(request)
    token = service.verify_otp(body.mobile_number, body.otp)
    if not token:
        audit.log(
            "admin_login_failed", "auth",
            details={"mobile": body.mobile_number},
            ip_address=ip,
            status="failure",
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired OTP.",
        )
    payload = decode_access_token(token)
    actor_id = int(payload["sub"]) if payload and "sub" in payload else None
    audit.log("admin_login", "auth", actor_user_id=actor_id, entity_id=actor_id, details={"mobile": body.mobile_number}, ip_address=ip)
    return TokenResponse(access_token=token)
