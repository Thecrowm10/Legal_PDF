from abc import ABC, abstractmethod
from typing import Optional

from app.models.document_type import DocumentType


class IDocumentTypeRepository(ABC):

    @abstractmethod
    def list_all(self) -> list[DocumentType]:
        ...

    @abstractmethod
    def get_by_id(self, type_id: int) -> Optional[DocumentType]:
        ...

    @abstractmethod
    def create(self, name: str, description: Optional[str] = None) -> DocumentType:
        ...

    @abstractmethod
    def toggle(self, type_id: int) -> Optional[DocumentType]:
        ...
