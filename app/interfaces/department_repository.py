from abc import ABC, abstractmethod
from typing import Optional

from app.models.department import Department


class IDepartmentRepository(ABC):

    @abstractmethod
    def get_by_id(self, department_id: int) -> Optional[Department]:
        ...

    @abstractmethod
    def create(self, name: str, description: Optional[str] = None) -> Department:
        ...

    @abstractmethod
    def list_all(self, skip: int = 0, limit: int = 100) -> list[Department]:
        ...

    @abstractmethod
    def toggle(self, department_id: int) -> Optional[Department]:
        ...
