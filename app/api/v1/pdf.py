import os
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile, status
from fastapi.responses import FileResponse

from app.core.config import settings
from app.core.dependencies import get_audit_service, get_current_user, get_pdf_service, require_roles
from app.models.user import User
from app.schemas.audit import AuditLogOut
from app.schemas.pdf import (
    DocumentNameItem,
    DocumentNameSearchResponse,
    FileUploadResponse,
    PDFCreateRequest,
    PDFListResponse,
    PDFReviewRequest,
    PDFUploadResponse,
    SearchResponse,
    SearchResultItem,
)
from app.services.audit_service import AuditService
from app.services.pdf_service import PDFService
from app.utils.request_utils import get_client_ip

router = APIRouter(prefix="/pdf", tags=["PDF Documents"])

ALLOWED_CONTENT_TYPES = {
    "application/pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
}

_approver_roles = require_roles("approver", "admin", "super_admin")


@router.post(
    "/upload-file",
    response_model=FileUploadResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Step 1 — Upload the PDF binary, receive a file_ref",
)
async def upload_file(
    request: Request,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
    audit: AuditService = Depends(get_audit_service),
):
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only PDF and Word (.docx) files are allowed",
        )
    try:
        result = await service.store_file(file)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc))
    audit.log(
        "pdf_uploaded", "pdf",
        actor_user_id=current_user.id,
        details={"original_filename": result.original_filename, "file_size": result.file_size, "file_ref": result.file_ref},
        ip_address=get_client_ip(request),
    )
    return result


@router.post(
    "/upload",
    response_model=PDFUploadResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Step 2 — Submit metadata with the file_ref from Step 1",
)
def create_document(
    body: PDFCreateRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
    audit: AuditService = Depends(get_audit_service),
):
    try:
        doc = service.create_from_ref(
            file_ref=body.file_ref,
            user_id=current_user.id,
            department_id=current_user.department_id,
            document_type_id=body.document_type_id,
            document_name=body.document_name,
            issue_date=body.issue_date,
            reference_number=body.reference_number,
            effective_from=body.effective_from,
            gazette_reference=body.gazette_reference,
            legal_authority=body.legal_authority,
            short_title=body.short_title,
            valid_until=body.valid_until,
            sector_domain=body.sector_domain,
            implementing_agency=body.implementing_agency,
            next_review_date=body.next_review_date,
            rule_making_authority=body.rule_making_authority,
            version_no=body.version_no,
            tag_ids=body.tag_ids,
            relationships=body.relationships,
            description=body.description,
        )
    except FileNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    audit.log(
        "pdf_created", "pdf",
        actor_user_id=current_user.id,
        entity_id=doc.id,
        details={"document_name": body.document_name, "document_type_id": body.document_type_id, "department_id": current_user.department_id, "file_ref": body.file_ref},
        ip_address=get_client_ip(request),
    )
    return doc


@router.get(
    "/pending",
    response_model=PDFListResponse,
    summary="Approver queue — documents awaiting review",
)
def list_pending_documents(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(_approver_roles),
    service: PDFService = Depends(get_pdf_service),
):
    total, documents = service.get_pending(skip, limit)
    return PDFListResponse(total=total, documents=documents)


@router.post(
    "/review",
    response_model=PDFUploadResponse,
    summary="Approve or reject a document",
)
def review_document(
    body: PDFReviewRequest,
    request: Request,
    current_user: User = Depends(_approver_roles),
    service: PDFService = Depends(get_pdf_service),
    audit: AuditService = Depends(get_audit_service),
):
    if body.action not in ("approved", "rejected"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="action must be 'approved' or 'rejected'",
        )
    doc = service.review_document(body.pdf_id, current_user.id, body.action, body.comments)
    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")
    audit.log(
        f"pdf_{body.action}", "pdf",
        actor_user_id=current_user.id,
        entity_id=body.pdf_id,
        details={"action": body.action, "comments": body.comments},
        ip_address=get_client_ip(request),
    )
    return doc


@router.get(
    "/approver/documents",
    response_model=PDFListResponse,
    summary="Approver — list all documents with optional status filter",
)
def list_documents_for_approver(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    status: Optional[str] = Query(None, description="Filter by status: pending | approved | rejected"),
    current_user: User = Depends(_approver_roles),
    service: PDFService = Depends(get_pdf_service),
):
    if status and status not in ("pending", "approved", "rejected"):
        raise HTTPException(
            status_code=400,
            detail="status must be one of: pending, approved, rejected",
        )
    total, documents = service.list_all_documents(skip, limit, status)
    return PDFListResponse(total=total, documents=documents)


VALID_DOCUMENT_TYPES = {"Act", "Amendment", "Notification", "Circular", "Policy", "Rules & Regulations", "Order/Gazette"}


@router.get("/search-documents", response_model=DocumentNameSearchResponse, summary="Autocomplete — search document names by type and keyword")
def search_documents_by_type(
    document_type: str = Query(..., description="Document type: Act | Amendment | Notification | Circular | Policy | Rules & Regulations | Order/Gazette"),
    q: str = Query(..., min_length=1, description="Keyword to match against document names"),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    if document_type not in VALID_DOCUMENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"document_type must be one of: {', '.join(sorted(VALID_DOCUMENT_TYPES))}",
        )
    rows = service.search_documents_by_type(document_type, q, limit)
    results = [
        DocumentNameItem(
            id=r["id"],
            document_name=r["document_name"],
            reference_number=r.get("reference_number"),
            status=r["status"],
            document_type_name=r.get("document_type_name"),
        )
        for r in rows
    ]
    return DocumentNameSearchResponse(query=q, document_type=document_type, total=len(results), results=results)


@router.get("/search", response_model=SearchResponse)
def search_pdfs(
    q: str = Query(..., min_length=2, description="Word or phrase to search across all PDFs"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    rows = service.search(q, skip, limit)
    results = [
        SearchResultItem(
            pdf_id=r["pdf_document_id"],
            original_filename=r["original_filename"],
            page_number=r["page_number"],
            relevance_score=r["relevance_score"],
            snippet=r["snippet"],
        )
        for r in rows
    ]
    return SearchResponse(query=q, total=len(results), results=results)


@router.get("/my-documents", response_model=PDFListResponse)
def list_my_documents(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    total, documents = service.list_my_documents(current_user.id, skip, limit)
    return PDFListResponse(total=total, documents=documents)


@router.get("/all", response_model=PDFListResponse)
def list_all_documents(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    status: Optional[str] = Query(None, description="Filter by status: pending | approved | rejected"),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    if status and status not in ("pending", "approved", "rejected"):
        raise HTTPException(
            status_code=400,
            detail="status must be one of: pending, approved, rejected",
        )
    total, documents = service.list_all_documents(skip, limit, status)
    return PDFListResponse(total=total, documents=documents)


@router.get("/{document_id}/file", summary="Stream the original PDF file")
def get_pdf_file(
    document_id: int,
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    doc = service.get_by_id(document_id)
    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")
    fp = doc.file_path if os.path.isabs(doc.file_path) else os.path.join(
        settings.UPLOAD_DIR, os.path.basename(doc.file_path)
    )
    if not os.path.exists(fp):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="File not found on server")
    return FileResponse(
        fp,
        media_type="application/pdf",
        filename=doc.original_filename or "document.pdf",
    )
