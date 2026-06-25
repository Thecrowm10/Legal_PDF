import os
import uuid
from datetime import date
from typing import Optional

from fastapi import UploadFile

from app.core.config import settings
from app.interfaces.pdf_page_repository import IPDFPageRepository
from app.interfaces.pdf_repository import IPDFRepository
from app.interfaces.tag_repository import ITagRepository
from app.models.pdf_document import PDFDocument
from app.schemas.pdf import FileUploadResponse
from app.services.pdf_extractor import extract_pages
from app.utils.text_utils import prepare_fts_query, build_snippet


class PDFService:

    def __init__(
        self,
        pdf_repo: IPDFRepository,
        page_repo: IPDFPageRepository,
        tag_repo: ITagRepository,
    ):
        self._pdf_repo = pdf_repo
        self._page_repo = page_repo
        self._tag_repo = tag_repo

    async def store_file(self, file: UploadFile) -> FileUploadResponse:
        os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
        unique_name = f"{uuid.uuid4().hex}_{file.filename}"
        file_path = os.path.join(settings.UPLOAD_DIR, unique_name)
        content = await file.read()
        with open(file_path, "wb") as f:
            f.write(content)
        return FileUploadResponse(
            file_ref=unique_name,
            original_filename=file.filename,
            file_size=len(content),
        )

    def create_from_ref(
        self,
        file_ref: str,
        user_id: int,
        act_name: str,
        gazette_reference: str,
        issuing_authority: str,
        enactment_date: date,
        version_no: Optional[str] = "1.0",
        department_id: Optional[int] = None,
        document_type_id: Optional[int] = None,
        tag_ids: Optional[list[int]] = None,
        description: Optional[str] = None,
    ) -> PDFDocument:
        file_path = os.path.join(settings.UPLOAD_DIR, file_ref)
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"File reference '{file_ref}' not found")

        file_size = os.path.getsize(file_path)
        original_filename = "_".join(file_ref.split("_")[1:]) if "_" in file_ref else file_ref

        doc = self._pdf_repo.create(
            filename=file_ref,
            original_filename=original_filename,
            file_path=file_path,
            file_size=file_size,
            uploaded_by=user_id,
            act_name=act_name,
            gazette_reference=gazette_reference,
            issuing_authority=issuing_authority,
            enactment_date=enactment_date,
            version_no=version_no,
            department_id=department_id,
            document_type_id=document_type_id,
            description=description,
        )

        if tag_ids:
            self._tag_repo.save_document_tags(doc.id, tag_ids)
            doc.tags = [t for t in self._tag_repo.list_all() if t.id in tag_ids]

        try:
            pages = [(num, txt) for num, txt in extract_pages(file_path) if txt.strip()]
            if pages:
                self._page_repo.save_pages(doc.id, pages)
        except Exception:
            pass

        return doc

    async def upload(
        self,
        file: UploadFile,
        user_id: int,
        act_name: Optional[str] = None,
        gazette_reference: Optional[str] = None,
        issuing_authority: Optional[str] = None,
        enactment_date: Optional[date] = None,
        version_no: Optional[str] = "1.0",
        department_id: Optional[int] = None,
        document_type_id: Optional[int] = None,
        tag_ids: Optional[list[int]] = None,
        description: Optional[str] = None,
    ) -> PDFDocument:
        os.makedirs(settings.UPLOAD_DIR, exist_ok=True)

        unique_name = f"{uuid.uuid4().hex}_{file.filename}"
        file_path = os.path.join(settings.UPLOAD_DIR, unique_name)

        content = await file.read()
        with open(file_path, "wb") as f:
            f.write(content)

        doc = self._pdf_repo.create(
            filename=unique_name,
            original_filename=file.filename,
            file_path=file_path,
            file_size=len(content),
            uploaded_by=user_id,
            act_name=act_name,
            gazette_reference=gazette_reference,
            issuing_authority=issuing_authority,
            enactment_date=enactment_date,
            version_no=version_no,
            department_id=department_id,
            document_type_id=document_type_id,
            description=description,
        )

        if tag_ids:
            self._tag_repo.save_document_tags(doc.id, tag_ids)
            doc.tags = [t for t in self._tag_repo.list_all() if t.id in tag_ids]

        try:
            pages = [(num, txt) for num, txt in extract_pages(file_path) if txt.strip()]
            if pages:
                self._page_repo.save_pages(doc.id, pages)
        except Exception:
            pass

        return doc

    def search(self, query: str, skip: int = 0, limit: int = 20) -> list[dict]:
        fts_term = prepare_fts_query(query)
        rows = self._page_repo.search(fts_term, skip, limit)
        for row in rows:
            row["snippet"] = build_snippet(row["page_text"], query)
        return rows

    def list_my_documents(self, user_id: int, skip: int = 0, limit: int = 100) -> list[PDFDocument]:
        return self._pdf_repo.list_by_user(user_id, skip, limit)

    def list_all_documents(self, skip: int = 0, limit: int = 100) -> list[PDFDocument]:
        return self._pdf_repo.list_all(skip, limit)
