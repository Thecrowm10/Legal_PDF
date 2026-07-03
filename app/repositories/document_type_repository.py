from typing import Optional

from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.interfaces.document_type_repository import IDocumentTypeRepository
from app.models.document_type import DocumentType


class DocumentTypeRepository(IDocumentTypeRepository):

    def __init__(self, db: Session):
        self._db = db

    def list_all(self) -> list[DocumentType]:
        result = self._db.execute(text("EXEC sp_list_document_types"))
        return [self._map_row(row) for row in result.mappings().fetchall()]

    def get_by_id(self, type_id: int) -> Optional[DocumentType]:
        result = self._db.execute(
            text("EXEC sp_get_document_type_by_id @type_id = :type_id"),
            {"type_id": type_id},
        )
        row = result.mappings().fetchone()
        return self._map_row(row) if row else None

    def create(self, name: str, description: Optional[str] = None) -> DocumentType:
        try:
            result = self._db.execute(
                text("EXEC sp_create_document_type @name = :name, @description = :description"),
                {"name": name, "description": description},
            )
            row = result.mappings().fetchone()
            self._db.commit()
            return self._map_row(row)
        except IntegrityError:
            self._db.rollback()
            raise ValueError("A document type with this name already exists")

    def toggle(self, type_id: int) -> Optional[DocumentType]:
        result = self._db.execute(
            text("EXEC sp_toggle_document_type_status @type_id = :type_id"),
            {"type_id": type_id},
        )
        row = result.mappings().fetchone()
        self._db.commit()
        return self._map_row(row) if row else None

    @staticmethod
    def _map_row(row) -> DocumentType:
        d = dict(row)
        dt = DocumentType(
            id=d["id"],
            name=d["name"],
            description=d.get("description"),
            created_at=d["created_at"],
        )
        dt.is_active = bool(d.get("is_active", True))
        return dt
