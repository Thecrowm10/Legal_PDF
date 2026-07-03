from abc import ABC, abstractmethod
from typing import Optional

from app.models.pdf_document import PDFDocument


class IPDFApprovalRepository(ABC):

    @abstractmethod
    def review(
        self,
        pdf_id: int,
        approver_id: int,
        action: str,
        comments: Optional[str] = None,
        annotations_json: Optional[str] = None,
    ) -> Optional[PDFDocument]:
        ...
