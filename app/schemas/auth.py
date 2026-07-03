from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr


class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class RoleOut(BaseModel):
    id: int
    name: str
    description: Optional[str] = None

    model_config = {"from_attributes": True}


class DepartmentOut(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    is_active: bool = True

    model_config = {"from_attributes": True}


class UserOut(BaseModel):
    id: int
    username: str
    email: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    is_active: bool
    must_change_password: bool = True
    role: Optional[RoleOut] = None
    department: Optional[DepartmentOut] = None
    departments: list[DepartmentOut] = []
    created_at: datetime
    last_login: Optional[datetime] = None

    model_config = {"from_attributes": True}


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


class ForgotPasswordRequest(BaseModel):
    identifier: str  # email address or mobile number


class ResetPasswordRequest(BaseModel):
    identifier: str  # same value used in forgot-password request
    otp: str
    new_password: str


class UserCreate(BaseModel):
    username: str
    email: EmailStr
    password: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    role_id: Optional[int] = None
    department_id: Optional[str] = None
    mobile_number: Optional[str] = None


class UserUpdate(BaseModel):
    user_id: int
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[EmailStr] = None
    is_active: Optional[bool] = None
    role_id: Optional[int] = None
    department_id: Optional[str] = None
    mobile_number: Optional[str] = None


class DepartmentCreate(BaseModel):
    name: str
    description: Optional[str] = None


class NodalOfficerDepartmentsUpdate(BaseModel):
    department_ids: list[int]


class AdminOtpRequest(BaseModel):
    mobile_number: str


class AdminOtpVerifyRequest(BaseModel):
    mobile_number: str
    otp: str
