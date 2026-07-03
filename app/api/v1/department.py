from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.dependencies import get_current_user, get_department_service
from app.models.user import User
from app.schemas.auth import DepartmentCreate, DepartmentOut
from app.services.department_service import DepartmentService

router = APIRouter(prefix="/departments", tags=["Departments"])


@router.post("/", response_model=DepartmentOut, status_code=status.HTTP_201_CREATED)
def create_department(
    body: DepartmentCreate,
    current_user: User = Depends(get_current_user),
    service: DepartmentService = Depends(get_department_service),
):
    try:
        return service.create(body.name, body.description)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))


@router.get("/", response_model=list[DepartmentOut])
def list_departments(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    service: DepartmentService = Depends(get_department_service),
):
    return service.list_all(skip, limit)


@router.get("/{department_id}", response_model=DepartmentOut)
def get_department(
    department_id: int,
    current_user: User = Depends(get_current_user),
    service: DepartmentService = Depends(get_department_service),
):
    dept = service.get_by_id(department_id)
    if not dept:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Department not found")
    return dept


@router.patch("/{department_id}/toggle", response_model=DepartmentOut)
def toggle_department(
    department_id: int,
    current_user: User = Depends(get_current_user),
    service: DepartmentService = Depends(get_department_service),
):
    dept = service.toggle(department_id)
    if not dept:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Department not found")
    return dept
