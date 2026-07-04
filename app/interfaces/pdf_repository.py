from abc import ABC, abstractmethod
from datetime import date
from typing import Optional

from app.models.pdf_document import PDFDocument


class IPDFRepository(ABC):

    @abstractmethod
    def create(
        self,
        filename: str,
        original_filename: str,
        file_path: str,
        file_size: int,
        uploaded_by: int,
        document_name: Optional[str] = None,
        reference_number: Optional[str] = None,
        issue_date: Optional[date] = None,
        effective_from: Optional[date] = None,
        gazette_reference: Optional[str] = None,
        legal_authority: Optional[str] = None,
        short_title: Optional[str] = None,
        valid_until: Optional[date] = None,
        sector_domain: Optional[str] = None,
        implementing_agency: Optional[str] = None,
        next_review_date: Optional[date] = None,
        rule_making_authority: Optional[str] = None,
        version_no: Optional[str] = "1.0",
        department_id: Optional[int] = None,
        document_type_id: Optional[int] = None,
        description: Optional[str] = None,
        summary: Optional[str] = None,  # auto-generated internally, not from request body
    ) -> PDFDocument:
        ...

    @abstractmethod
    def get_by_id(self, document_id: int) -> Optional[PDFDocument]:
        ...

    @abstractmethod
    def list_by_user(self, user_id: int, skip: int = 0, limit: int = 100) -> tuple[int, list[PDFDocument]]:
        ...

    @abstractmethod
    def list_all(self, skip: int = 0, limit: int = 100, status: Optional[str] = None) -> tuple[int, list[PDFDocument]]:
        ...

    @abstractmethod
    def get_pending(self, skip: int = 0, limit: int = 100) -> tuple[int, list[PDFDocument]]:
        ...

    @abstractmethod
    def save_relationships(self, pdf_id: int, relationships: list[dict]) -> None:
        ...

    @abstractmethod
    def search_documents_by_type(self, document_type: str, q: str, limit: int = 20) -> list[dict]:
        ...

    @abstractmethod
    def check_duplicate(self, document_name: str, document_type_id: int, caller_dept_id: int) -> list[dict]:
        ...

    @abstractmethod
    def link_to_department(self, pdf_id: int, department_id: int, user_id: int) -> dict:
        ...

    @abstractmethod
    def get_links_for_department(self, department_id: int, status: str | None = "pending") -> list[dict]:
        ...

    @abstractmethod
    def review_department_link(self, link_id: int, action: str, reviewed_by: int, comments: str | None = None, annotations_json: str | None = None) -> None:
        ...

    @abstractmethod
    def get_linked_documents_for_department(self, department_id: int, status: str | None = None) -> list[dict]:
        ...

    @abstractmethod
    def get_all_department_links(self, status: str | None = None, department_id: int | None = None) -> list[dict]:
        ...
