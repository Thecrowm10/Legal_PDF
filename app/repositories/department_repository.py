from typing import Optional

from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.interfaces.department_repository import IDepartmentRepository
from app.models.department import Department


class DepartmentRepository(IDepartmentRepository):

    def __init__(self, db: Session):
        self._db = db

    def get_by_id(self, department_id: int) -> Optional[Department]:
        result = self._db.execute(
            text("EXEC sp_get_department_by_id @department_id = :department_id"),
            {"department_id": department_id},
        )
        row = result.mappings().fetchone()
        return self._map_row(row) if row else None

    def create(self, name: str, description: Optional[str] = None) -> Department:
        try:
            result = self._db.execute(
                text("EXEC sp_create_department @name = :name, @description = :description"),
                {"name": name, "description": description},
            )
            row = result.mappings().fetchone()
            self._db.commit()
            return self._map_row(row)
        except IntegrityError:
            self._db.rollback()
            raise ValueError(f"Department '{name}' already exists")

    def list_all(self, skip: int = 0, limit: int = 100) -> list[Department]:
        result = self._db.execute(
            text("EXEC sp_list_departments @skip = :skip, @limit = :limit"),
            {"skip": skip, "limit": limit},
        )
        return [self._map_row(row) for row in result.mappings().fetchall()]

    def toggle(self, department_id: int) -> Optional[Department]:
        result = self._db.execute(
            text("EXEC sp_toggle_department_status @department_id = :department_id"),
            {"department_id": department_id},
        )
        row = result.mappings().fetchone()
        self._db.commit()
        return self._map_row(row) if row else None

    @staticmethod
    def _map_row(row) -> Department:
        d = dict(row)
        dept = Department(
            id=d["id"],
            name=d["name"],
            description=d.get("description"),
            created_at=d["created_at"],
        )
        dept.is_active = bool(d.get("is_active", True))
        return dept
