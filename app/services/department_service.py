from typing import Optional  # noqa: F401 — used in toggle return type

from app.interfaces.department_repository import IDepartmentRepository
from app.models.department import Department


class DepartmentService:

    def __init__(self, repo: IDepartmentRepository):
        self._repo = repo

    def create(self, name: str, description: Optional[str] = None) -> Department:
        return self._repo.create(name, description)

    def get_by_id(self, department_id: int) -> Optional[Department]:
        return self._repo.get_by_id(department_id)

    def list_all(self, skip: int = 0, limit: int = 100) -> list[Department]:
        return self._repo.list_all(skip, limit)

    def toggle(self, department_id: int) -> Optional[Department]:
        return self._repo.toggle(department_id)
