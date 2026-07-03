from fastapi import APIRouter, Depends, HTTPException, Query, Request, status

from app.core.dependencies import get_audit_service, get_current_user, get_user_repository, require_roles
from app.interfaces.user_repository import IUserRepository
from app.models.user import User
from app.schemas.auth import DepartmentOut, NodalOfficerDepartmentsUpdate, UserOut, UserUpdate
from app.services.audit_service import AuditService
from app.utils.request_utils import get_client_ip

router = APIRouter(prefix="/users", tags=["Users"])

_manage_users = require_roles("super Admin", "admin", "nodal Officer")
_admin_only   = require_roles("super Admin", "admin")


def _is_nodal_officer(user: User) -> bool:
    return user.role is not None and user.role.name == "nodal Officer"


def _managed_dept_ids(user: User) -> set[int]:
    return {d.id for d in getattr(user, "managed_departments", [])}


def _assert_in_managed_departments(current_user: User, target: User) -> None:
    """Raise 403 if a nodal officer tries to act on a user outside their managed departments."""
    if _is_nodal_officer(current_user) and target.department_id not in _managed_dept_ids(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Nodal officers can only manage users within their assigned departments",
        )


@router.get("/", response_model=list[UserOut])
def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(_manage_users),
    repo: IUserRepository = Depends(get_user_repository),
):
    dept_filter: str | None = None
    if _is_nodal_officer(current_user):
        managed = getattr(current_user, "managed_departments", [])
        dept_filter = ",".join(str(d.id) for d in managed)

    return repo.list_all(skip, limit, exclude_user_id=current_user.id, department_ids=dept_filter)


@router.get("/{user_id}", response_model=UserOut)
def get_user(
    user_id: int,
    current_user: User = Depends(_manage_users),
    repo: IUserRepository = Depends(get_user_repository),
):
    user = repo.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    _assert_in_managed_departments(current_user, user)
    return user


@router.patch("/", response_model=UserOut)
def update_user(
    body: UserUpdate,
    request: Request,
    current_user: User = Depends(_manage_users),
    repo: IUserRepository = Depends(get_user_repository),
    audit: AuditService = Depends(get_audit_service),
):
    target = repo.get_by_id(body.user_id)
    if not target:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    _assert_in_managed_departments(current_user, target)

    if _is_nodal_officer(current_user):
        if body.role_id is not None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Nodal officers cannot change a user's role",
            )
        if body.department_id is not None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Nodal officers cannot transfer users to another department",
            )

    changes: dict = {}
    if body.first_name is not None and body.first_name != target.first_name:
        changes["first_name"] = {"old": target.first_name, "new": body.first_name}
    if body.last_name is not None and body.last_name != target.last_name:
        changes["last_name"] = {"old": target.last_name, "new": body.last_name}
    if body.email is not None and body.email != target.email:
        changes["email"] = {"old": target.email, "new": body.email}
    if body.is_active is not None and body.is_active != target.is_active:
        changes["is_active"] = {"old": target.is_active, "new": body.is_active}
    if body.role_id is not None and body.role_id != target.role_id:
        changes["role_id"] = {"old": target.role_id, "new": body.role_id}
    if body.department_id is not None and body.department_id != target.department_id:
        changes["department_id"] = {"old": target.department_id, "new": body.department_id}

    try:
        user = repo.update(
            body.user_id,
            first_name=body.first_name,
            last_name=body.last_name,
            email=body.email,
            is_active=body.is_active,
            role_id=body.role_id,
            department_id=body.department_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    audit.log(
        "user_updated", "user",
        actor_user_id=current_user.id,
        entity_id=body.user_id,
        details={"target_username": target.username, "changes": changes},
        ip_address=get_client_ip(request),
    )
    return user


@router.get("/{user_id}/managed-departments", response_model=list[DepartmentOut])
def get_managed_departments(
    user_id: int,
    current_user: User = Depends(_admin_only),
    repo: IUserRepository = Depends(get_user_repository),
):
    """Return the list of departments a nodal officer is assigned to manage."""
    target = repo.get_by_id(user_id)
    if not target:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return repo.get_managed_departments(user_id)


@router.put("/{user_id}/managed-departments", response_model=UserOut)
def set_managed_departments(
    user_id: int,
    body: NodalOfficerDepartmentsUpdate,
    request: Request,
    current_user: User = Depends(_admin_only),
    repo: IUserRepository = Depends(get_user_repository),
    audit: AuditService = Depends(get_audit_service),
):
    """Replace the full set of departments a nodal officer manages. Admin/super Admin only."""
    target = repo.get_by_id(user_id)
    if not target:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if not target.role or target.role.name != "nodal Officer":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Managed departments can only be assigned to nodal officers",
        )

    repo.set_managed_departments(user_id, body.department_ids)

    audit.log(
        "nodal_officer_departments_updated", "user",
        actor_user_id=current_user.id,
        entity_id=user_id,
        details={"target_username": target.username, "department_ids": body.department_ids},
        ip_address=get_client_ip(request),
    )

    return repo.get_by_id(user_id)
