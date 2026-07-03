from datetime import datetime, timedelta, timezone
from typing import Optional

import bcrypt
import jwt
from jwt.exceptions import InvalidTokenError

from app.core.config import settings

PASSWORD_EXPIRY_DAYS = 180  # 6 months


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(plain_password.encode("utf-8"), hashed_password.encode("utf-8"))


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_access_token(token: str) -> Optional[dict]:
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except InvalidTokenError:
        return None


def is_password_expired(user) -> bool:
    """Return True if the user's password is older than PASSWORD_EXPIRY_DAYS."""
    ts = user.password_changed_at
    if ts is None:
        return False
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    return ts < datetime.now(timezone.utc) - timedelta(days=PASSWORD_EXPIRY_DAYS)


def build_user_token(user) -> str:
    """Build a JWT for a user, factoring in both the DB flag and 6-month expiry."""
    expired = is_password_expired(user)
    must_change = user.must_change_password or expired
    ts = user.password_changed_at
    if ts and ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    all_depts = getattr(user, "departments", None) or []
    return create_access_token({
        "sub":                  str(user.id),
        "username":             user.username,
        "email":                user.email,
        "is_active":            user.is_active,
        "must_change_password": must_change,
        "password_expired":     expired,
        "role_id":              user.role_id,
        "role":                 user.role.name if user.role else None,
        "department_id":        user.department_id,
        "departments":          [{"id": d.id, "name": d.name} for d in all_depts],
    })
