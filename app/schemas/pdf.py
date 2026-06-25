from datetime import datetime, date
from typing import Optional
from pydantic import BaseModel

from app.schemas.tag import TagRef


class FileUploadResponse(BaseModel):
    file_ref: str
    original_filename: str
    file_size: int


class PDFCreateRequest(BaseModel):
    file_ref: str
    act_name: str
    gazette_reference: str
    issuing_authority: str
    enactment_date: date
    version_no: Optional[str] = "1.0"
    department_id: Optional[int] = None
    document_type_id: Optional[int] = None
    tag_ids: Optional[list[int]] = None
    description: Optional[str] = None


class PDFUploadResponse(BaseModel):
    id: int
    filename: str
    original_filename: str
    file_size: int
    act_name: Optional[str] = None
    gazette_reference: Optional[str] = None
    issuing_authority: Optional[str] = None
    enactment_date: Optional[date] = None
    version_no: Optional[str] = None
    department_id: Optional[int] = None
    department_name: Optional[str] = None
    document_type_id: Optional[int] = None
    document_type_name: Optional[str] = None
    tags: list[TagRef] = []
    description: Optional[str] = None
    uploaded_by: int
    created_at: datetime

    model_config = {"from_attributes": True}


class PDFListItem(BaseModel):
    id: int
    original_filename: str
    file_size: int
    act_name: Optional[str] = None
    gazette_reference: Optional[str] = None
    issuing_authority: Optional[str] = None
    enactment_date: Optional[date] = None
    version_no: Optional[str] = None
    department_id: Optional[int] = None
    department_name: Optional[str] = None
    document_type_id: Optional[int] = None
    document_type_name: Optional[str] = None
    tags: list[TagRef] = []
    description: Optional[str] = None
    uploaded_by: int
    created_at: datetime

    model_config = {"from_attributes": True}


class SearchResultItem(BaseModel):
    pdf_id: int
    original_filename: str
    page_number: int
    relevance_score: int
    snippet: str


class SearchResponse(BaseModel):
    query: str
    total: int
    results: list[SearchResultItem]
