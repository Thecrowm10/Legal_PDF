from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.dependencies import get_current_user, get_user_repository, require_roles
from app.interfaces.user_repository import IUserRepository
from app.models.user import User
from app.schemas.auth import UserOut, UserUpdate

router = APIRouter(prefix="/users", tags=["Users"])

_manage_users = require_roles("super_admin", "admin", "nodal_officer")
_admin_only   = require_roles("super_admin", "admin")


def _is_nodal_officer(user: User) -> bool:
    return user.role is not None and user.role.name == "nodal_officer"


def _assert_same_department(current_user: User, target: User) -> None:
    """Raise 403 if a nodal officer tries to act on a user outside their department."""
    if _is_nodal_officer(current_user) and target.department_id != current_user.department_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Nodal officers can only manage users within their own department",
        )


@router.get("/", response_model=list[UserOut])
def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(_manage_users),
    repo: IUserRepository = Depends(get_user_repository),
):
    # Nodal officer sees only their department; admin/super_admin see all
    dept_filter = current_user.department_id if _is_nodal_officer(current_user) else None
    return repo.list_all(skip, limit, exclude_user_id=current_user.id, department_id=dept_filter)


@router.get("/{user_id}", response_model=UserOut)
def get_user(
    user_id: int,
    current_user: User = Depends(_manage_users),
    repo: IUserRepository = Depends(get_user_repository),
):
    user = repo.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    _assert_same_department(current_user, user)
    return user


@router.patch("/", response_model=UserOut)
def update_user(
    body: UserUpdate,
    current_user: User = Depends(_manage_users),
    repo: IUserRepository = Depends(get_user_repository),
):
    target = repo.get_by_id(body.user_id)
    if not target:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    _assert_same_department(current_user, target)

    if _is_nodal_officer(current_user):
        # Nodal officers cannot change role or move a user to another department
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
    return user
