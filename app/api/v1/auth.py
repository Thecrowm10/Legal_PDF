import logging

from fastapi import APIRouter, Depends, HTTPException, Request, status

logger = logging.getLogger(__name__)

from app.core.dependencies import get_audit_service, get_auth_service, get_current_user, get_reset_service
from app.core.security import decode_access_token
from app.models.user import User
from app.schemas.auth import (
    ChangePasswordRequest,
    ForgotPasswordRequest,
    LoginRequest,
    ResetPasswordRequest,
    TokenResponse,
    UserCreate,
    UserOut,
)
from app.services.audit_service import AuditService
from app.services.auth_service import AuthService
from app.services.reset_service import ResetService
from app.utils.request_utils import get_client_ip

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def register(
    body: UserCreate,
    request: Request,
    service: AuthService = Depends(get_auth_service),
    audit: AuditService = Depends(get_audit_service),
):
    try:
        user = service.register(
            body.username, body.email, body.password,
            body.first_name, body.last_name,
            body.role_id, body.department_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    audit.log(
        "user_registered", "user",
        entity_id=user.id,
        details={"username": user.username, "email": user.email, "role_id": body.role_id, "department_id": body.department_id},
        ip_address=get_client_ip(request),
    )
    return user


@router.post("/login", response_model=TokenResponse)
def login(
    body: LoginRequest,
    request: Request,
    service: AuthService = Depends(get_auth_service),
    audit: AuditService = Depends(get_audit_service),
):
    ip = get_client_ip(request)
    token = service.login(body.username, body.password, ip)
    if not token:
        audit.log(
            "login_failed", "auth",
            details={"username": body.username},
            ip_address=ip,
            status="failure",
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    payload = decode_access_token(token)
    actor_id = int(payload["sub"]) if payload and "sub" in payload else None
    audit.log("login", "auth", actor_user_id=actor_id, entity_id=actor_id, details={"username": body.username}, ip_address=ip)
    return TokenResponse(access_token=token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    request: Request,
    current_user: User = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
    audit: AuditService = Depends(get_audit_service),
):
    ip = get_client_ip(request)
    service.logout(current_user.id, ip)
    audit.log("logout", "auth", actor_user_id=current_user.id, entity_id=current_user.id, ip_address=ip)


@router.post("/change-password", response_model=TokenResponse)
def change_password(
    body: ChangePasswordRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
    audit: AuditService = Depends(get_audit_service),
):
    ip = get_client_ip(request)
    token = service.change_password(current_user.id, body.current_password, body.new_password)
    if not token:
        audit.log("password_change_failed", "user", actor_user_id=current_user.id, entity_id=current_user.id, ip_address=ip, status="failure")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect",
        )
    audit.log("password_changed", "user", actor_user_id=current_user.id, entity_id=current_user.id, ip_address=ip)
    return TokenResponse(access_token=token)


@router.post("/forgot-password")
def forgot_password(
    body: ForgotPasswordRequest,
    request: Request,
    service: ResetService = Depends(get_reset_service),
    audit: AuditService = Depends(get_audit_service),
):
    ip = get_client_ip(request)
    try:
        channel = service.request_otp(body.identifier)
    except ValueError as exc:
        audit.log("forgot_password_failed", "auth", details={"identifier": body.identifier, "error": str(exc)}, ip_address=ip, status="failure")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    except Exception as exc:
        logger.exception("[forgot-password] Unexpected error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Could not send OTP. Please try again later.",
        )
    audit.log("forgot_password", "auth", details={"identifier": body.identifier, "channel": channel}, ip_address=ip)
    masked = _mask_identifier(body.identifier)
    return {"message": f"OTP sent to your {channel} ({masked})", "channel": channel}


@router.post("/reset-password", response_model=TokenResponse)
def reset_password(
    body: ResetPasswordRequest,
    request: Request,
    service: ResetService = Depends(get_reset_service),
    audit: AuditService = Depends(get_audit_service),
):
    ip = get_client_ip(request)
    if len(body.new_password) < 8:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Password must be at least 8 characters.")
    token = service.verify_and_reset(body.identifier, body.otp, body.new_password)
    if not token:
        audit.log("password_reset_failed", "auth", details={"identifier": body.identifier}, ip_address=ip, status="failure")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP. Please request a new one.",
        )
    payload = decode_access_token(token)
    actor_id = int(payload["sub"]) if payload and "sub" in payload else None
    audit.log("password_reset", "auth", actor_user_id=actor_id, entity_id=actor_id, details={"identifier": body.identifier}, ip_address=ip)
    return TokenResponse(access_token=token)


@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


def _mask_identifier(identifier: str) -> str:
    if "@" in identifier:
        local, domain = identifier.split("@", 1)
        return local[:2] + "***@" + domain
    return identifier[:3] + "****" + identifier[-2:]
