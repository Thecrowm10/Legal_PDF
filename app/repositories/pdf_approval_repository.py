from typing import Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.interfaces.pdf_approval_repository import IPDFApprovalRepository
from app.models.pdf_document import PDFDocument
from app.repositories.pdf_repository import PDFRepository


class PDFApprovalRepository(IPDFApprovalRepository):

    def __init__(self, db: Session):
        self._db = db

    def review(
        self,
        pdf_id: int,
        approver_id: int,
        action: str,
        comments: Optional[str] = None,
        annotations_json: Optional[str] = None,
    ) -> Optional[PDFDocument]:
        result = self._db.execute(
            text(
                "EXEC sp_review_pdf_document "
                "@pdf_id = :pdf_id, @approver_id = :approver_id, "
                "@action = :action, @comments = :comments, "
                "@annotations_json = :annotations_json"
            ),
            {
                "pdf_id": pdf_id,
                "approver_id": approver_id,
                "action": action,
                "comments": comments,
                "annotations_json": annotations_json,
            },
        )
        row = result.mappings().fetchone()
        self._db.commit()
        return PDFRepository._map_row(row) if row else None
