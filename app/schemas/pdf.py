from datetime import datetime, date
from typing import Optional
from pydantic import BaseModel

from app.schemas.tag import TagRef


# ── File upload (Step 1) ─────────────────────────────────────

class FileUploadResponse(BaseModel):
    file_ref: str
    original_filename: str
    file_size: int
    summary: Optional[str] = None


# ── Approval ─────────────────────────────────────────────────

class ApprovalInfo(BaseModel):
    action: str
    comments: Optional[str] = None
    annotations_json: Optional[str] = None
    acted_at: datetime
    approver_username: str
    approver_first_name: Optional[str] = None
    approver_last_name: Optional[str] = None


class PDFReviewRequest(BaseModel):
    pdf_id: int
    action: str                  # 'approved' | 'rejected'
    comments: Optional[str] = None
    annotations_json: Optional[str] = None


# ── Relationships ────────────────────────────────────────────

class RelationshipInput(BaseModel):
    pdf_id: int
    type: str = "related"   # parent_act | amends | implements | related


class RelationshipRef(BaseModel):
    pdf_id: int
    document_name: Optional[str] = None
    type: str


# ── Document create request (Step 2) ─────────────────────────

class PDFCreateRequest(BaseModel):
    file_ref: str
    document_type_id: int
    document_name: str
    issue_date: date

    # Shared optional fields
    reference_number: Optional[str] = None
    effective_from: Optional[date] = None
    gazette_reference: Optional[str] = None
    legal_authority: Optional[str] = None
    version_no: Optional[str] = "1.0"

    # Act-specific
    short_title: Optional[str] = None

    # Circular-specific
    valid_until: Optional[date] = None

    # Policy-specific
    sector_domain: Optional[str] = None
    implementing_agency: Optional[str] = None
    next_review_date: Optional[date] = None

    # Rules & Regulations-specific
    rule_making_authority: Optional[str] = None

    # Common
    tag_ids: Optional[list[int]] = None
    relationships: Optional[list[RelationshipInput]] = None
    description: Optional[str] = None


# ── Responses ────────────────────────────────────────────────

class PDFUploadResponse(BaseModel):
    id: int
    filename: str
    original_filename: str
    file_size: int
    status: str = "pending"

    document_name: Optional[str] = None
    issue_date: Optional[date] = None
    reference_number: Optional[str] = None
    effective_from: Optional[date] = None
    gazette_reference: Optional[str] = None
    legal_authority: Optional[str] = None
    short_title: Optional[str] = None
    valid_until: Optional[date] = None
    sector_domain: Optional[str] = None
    implementing_agency: Optional[str] = None
    next_review_date: Optional[date] = None
    rule_making_authority: Optional[str] = None
    version_no: Optional[str] = None

    department_id: Optional[int] = None
    department_name: Optional[str] = None
    document_type_id: Optional[int] = None
    document_type_name: Optional[str] = None
    tags: list[TagRef] = []
    relationships: list[RelationshipRef] = []
    latest_approval: Optional[ApprovalInfo] = None
    description: Optional[str] = None
    summary: Optional[str] = None
    uploaded_by: int
    created_at: datetime

    model_config = {"from_attributes": True}


class PDFListItem(BaseModel):
    id: int
    original_filename: str
    file_path: Optional[str] = None
    file_size: int
    status: str = "pending"

    document_name: Optional[str] = None
    issue_date: Optional[date] = None
    reference_number: Optional[str] = None
    effective_from: Optional[date] = None
    gazette_reference: Optional[str] = None
    legal_authority: Optional[str] = None
    short_title: Optional[str] = None
    valid_until: Optional[date] = None
    sector_domain: Optional[str] = None
    implementing_agency: Optional[str] = None
    next_review_date: Optional[date] = None
    rule_making_authority: Optional[str] = None
    version_no: Optional[str] = None

    department_id: Optional[int] = None
    department_name: Optional[str] = None
    document_type_id: Optional[int] = None
    document_type_name: Optional[str] = None
    tags: list[TagRef] = []
    relationships: list[RelationshipRef] = []
    latest_approval: Optional[ApprovalInfo] = None
    description: Optional[str] = None
    summary: Optional[str] = None
    uploaded_by: int
    created_at: datetime
    uploader_username: Optional[str] = None
    uploader_first_name: Optional[str] = None
    uploader_last_name: Optional[str] = None

    model_config = {"from_attributes": True}


class PDFListResponse(BaseModel):
    total: int
    documents: list[PDFListItem]


# ── Department linking ────────────────────────────────────────

class DuplicateCheckItem(BaseModel):
    id: int
    document_name: str
    version_no: Optional[str] = None
    status: str
    created_at: datetime
    department_id: Optional[int] = None
    department_name: Optional[str] = None
    document_type_name: Optional[str] = None
    uploader_username: Optional[str] = None
    match_type: str   # 'own_dept' | 'other_dept'


class LinkDocumentRequest(BaseModel):
    pdf_id: int


class LinkReviewRequest(BaseModel):
    link_id: int
    action: str                         # 'approved' | 'rejected'
    comments: Optional[str] = None
    annotations_json: Optional[str] = None


class DepartmentLinkItem(BaseModel):
    link_id: int
    pdf_id: int
    link_status: str
    requested_at: datetime
    reviewed_at: Optional[datetime] = None
    review_comments: Optional[str] = None
    annotations_json: Optional[str] = None
    document_name: Optional[str] = None
    version_no: Optional[str] = None
    document_status: str
    document_type_name: Optional[str] = None
    original_department_name: Optional[str] = None
    requested_by_username: Optional[str] = None
    requested_by_first_name: Optional[str] = None
    requested_by_last_name: Optional[str] = None
    reviewed_by_username: Optional[str] = None
    reviewed_by_first_name: Optional[str] = None
    reviewed_by_last_name: Optional[str] = None


class AllDepartmentLinkItem(BaseModel):
    link_id: int
    pdf_id: int
    link_status: str
    requested_at: datetime
    reviewed_at: Optional[datetime] = None
    review_comments: Optional[str] = None
    annotations_json: Optional[str] = None
    document_name: Optional[str] = None
    version_no: Optional[str] = None
    document_status: str
    document_type_name: Optional[str] = None
    original_department_name: Optional[str] = None
    linked_department_name: Optional[str] = None
    requested_by_username: Optional[str] = None
    requested_by_first_name: Optional[str] = None
    requested_by_last_name: Optional[str] = None
    reviewed_by_username: Optional[str] = None
    reviewed_by_first_name: Optional[str] = None
    reviewed_by_last_name: Optional[str] = None


class LinkedDocumentItem(BaseModel):
    """A pdf_documents row returned via sp_get_linked_documents_for_department.
    Carries the extra link_id / link_status columns on top of the standard fields."""
    id: int
    original_filename: str
    file_path: Optional[str] = None
    file_size: int
    status: str
    document_name: Optional[str] = None
    version_no: Optional[str] = None
    reference_number: Optional[str] = None
    issue_date: Optional[date] = None
    document_type_id: Optional[int] = None
    document_type_name: Optional[str] = None
    department_id: Optional[int] = None
    department_name: Optional[str] = None
    uploaded_by: int
    uploader_username: Optional[str] = None
    uploader_first_name: Optional[str] = None
    uploader_last_name: Optional[str] = None
    created_at: datetime
    link_id: int
    link_status: str
    review_comments: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    link_annotations_json: Optional[str] = None
    link_reviewed_by_username: Optional[str] = None
    link_reviewed_by_first_name: Optional[str] = None
    link_reviewed_by_last_name: Optional[str] = None

    model_config = {"from_attributes": True}


class DocumentNameItem(BaseModel):
    id: int
    document_name: str
    reference_number: Optional[str] = None
    status: str
    document_type_name: Optional[str] = None


class DocumentNameSearchResponse(BaseModel):
    query: str
    document_type: str
    total: int
    results: list[DocumentNameItem]


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
