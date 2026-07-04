import os
import uuid
from datetime import date
from typing import Optional

from fastapi import UploadFile

from app.core.config import settings
from app.interfaces.pdf_approval_repository import IPDFApprovalRepository
from app.interfaces.pdf_page_repository import IPDFPageRepository
from app.interfaces.pdf_repository import IPDFRepository
from app.interfaces.tag_repository import ITagRepository
from app.models.pdf_document import PDFDocument
from app.schemas.pdf import FileUploadResponse, RelationshipInput
from app.services.pdf_extractor import extract_pages
from app.services.pdf_summarizer import summarize_document
from app.utils.text_utils import prepare_fts_query, build_snippet


class PDFService:

    def __init__(
        self,
        pdf_repo: IPDFRepository,
        page_repo: IPDFPageRepository,
        tag_repo: ITagRepository,
        approval_repo: IPDFApprovalRepository,
    ):
        self._pdf_repo = pdf_repo
        self._page_repo = page_repo
        self._tag_repo = tag_repo
        self._approval_repo = approval_repo

    async def store_file(self, file: UploadFile) -> FileUploadResponse:
        os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
        unique_name = f"{uuid.uuid4().hex}_{file.filename}"
        file_path = os.path.join(settings.UPLOAD_DIR, unique_name)
        content = await file.read()
        with open(file_path, "wb") as f:
            f.write(content)

        # Extract text — reject the file early if nothing is readable
        pages: list[tuple[int, str]] = []
        try:
            pages = [(num, txt) for num, txt in extract_pages(file_path) if txt.strip()]
        except Exception:
            pass

        if not pages:
            try:
                os.remove(file_path)
            except OSError:
                pass
            raise ValueError(
                "File is not OCR Enabled. No readable text could be extracted. "
                "Please upload another file."
            )

        combined_text = "\n".join(txt for _, txt in pages)
        summary: str | None = None
        try:
            summary = summarize_document(combined_text)
        except Exception:
            pass

        return FileUploadResponse(
            file_ref=unique_name,
            original_filename=file.filename,
            file_size=len(content),
            summary=summary,
        )

    def create_from_ref(
        self,
        file_ref: str,
        user_id: int,
        department_id: Optional[int],
        document_type_id: int,
        document_name: str,
        issue_date: date,
        reference_number: Optional[str] = None,
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
        tag_ids: Optional[list[int]] = None,
        relationships: Optional[list[RelationshipInput]] = None,
        description: Optional[str] = None,
    ) -> PDFDocument:
        file_path = os.path.join(settings.UPLOAD_DIR, file_ref)
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"File reference '{file_ref}' not found. Upload the file first.")

        file_size = os.path.getsize(file_path)
        original_filename = "_".join(file_ref.split("_")[1:]) if "_" in file_ref else file_ref

        pages: list[tuple[int, str]] = []
        try:
            pages = [(num, txt) for num, txt in extract_pages(file_path) if txt.strip()]
        except Exception:
            pass

        summary: str | None = None
        if pages:
            combined_text = "\n".join(txt for _, txt in pages)
            summary = summarize_document(combined_text)

        doc = self._pdf_repo.create(
            filename=file_ref,
            original_filename=original_filename,
            file_path=file_path,
            file_size=file_size,
            uploaded_by=user_id,
            document_name=document_name,
            reference_number=reference_number,
            issue_date=issue_date,
            effective_from=effective_from,
            gazette_reference=gazette_reference,
            legal_authority=legal_authority,
            short_title=short_title,
            valid_until=valid_until,
            sector_domain=sector_domain,
            implementing_agency=implementing_agency,
            next_review_date=next_review_date,
            rule_making_authority=rule_making_authority,
            version_no=version_no,
            department_id=department_id,
            document_type_id=document_type_id,
            description=description,
            summary=summary,
        )

        if pages:
            self._page_repo.save_pages(doc.id, pages)

        if tag_ids:
            self._tag_repo.save_document_tags(doc.id, tag_ids)
            doc.tags = [t for t in self._tag_repo.list_all() if t.id in tag_ids]

        if relationships:
            rels = [{"pdf_id": r.pdf_id, "type": r.type} for r in relationships]
            self._pdf_repo.save_relationships(doc.id, rels)
            doc.relationships = [
                type("R", (), {"pdf_id": r.pdf_id, "document_name": None, "type": r.type})()
                for r in relationships
            ]

        return doc

    def search_documents_by_type(self, document_type: str, q: str, limit: int = 20) -> list[dict]:
        return self._pdf_repo.search_documents_by_type(document_type, q, limit)

    def search(self, query: str, skip: int = 0, limit: int = 20) -> list[dict]:
        fts_term = prepare_fts_query(query)
        rows = self._page_repo.search(fts_term, skip, limit)
        for row in rows:
            row["snippet"] = build_snippet(row["page_text"], query)
        return rows

    def review_document(
        self,
        pdf_id: int,
        approver_id: int,
        action: str,
        comments: Optional[str] = None,
        annotations_json: Optional[str] = None,
    ) -> Optional[PDFDocument]:
        if action not in ("approved", "rejected"):
            raise ValueError("action must be 'approved' or 'rejected'")
        return self._approval_repo.review(pdf_id, approver_id, action, comments, annotations_json)

    def get_by_id(self, document_id: int) -> Optional[PDFDocument]:
        return self._pdf_repo.get_by_id(document_id)

    def get_pending(self, skip: int = 0, limit: int = 100) -> tuple[int, list[PDFDocument]]:
        return self._pdf_repo.get_pending(skip, limit)

    def list_my_documents(self, user_id: int, skip: int = 0, limit: int = 100) -> tuple[int, list[PDFDocument]]:
        return self._pdf_repo.list_by_user(user_id, skip, limit)

    def list_all_documents(self, skip: int = 0, limit: int = 100, status: Optional[str] = None) -> tuple[int, list[PDFDocument]]:
        return self._pdf_repo.list_all(skip, limit, status)

    def check_duplicate_document(self, document_name: str, document_type_id: int, caller_dept_id: int) -> list[dict]:
        return self._pdf_repo.check_duplicate(document_name, document_type_id, caller_dept_id)

    def link_document_to_department(self, pdf_id: int, department_id: int, user_id: int) -> dict:
        return self._pdf_repo.link_to_department(pdf_id, department_id, user_id)

    def get_links_for_department(self, department_id: int, status: str | None = "pending") -> list[dict]:
        return self._pdf_repo.get_links_for_department(department_id, status)

    def review_department_link(self, link_id: int, action: str, reviewed_by: int, comments: str | None = None, annotations_json: str | None = None) -> None:
        if action not in ("approved", "rejected"):
            raise ValueError("action must be 'approved' or 'rejected'")
        self._pdf_repo.review_department_link(link_id, action, reviewed_by, comments, annotations_json)

    def get_linked_documents_for_department(self, department_id: int, status: str | None = None) -> list[dict]:
        return self._pdf_repo.get_linked_documents_for_department(department_id, status)

    def get_all_department_links(self, status: str | None = None, department_id: int | None = None) -> list[dict]:
        return self._pdf_repo.get_all_department_links(status, department_id)
