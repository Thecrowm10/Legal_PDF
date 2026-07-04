import os
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile, status
from fastapi.responses import FileResponse

from app.core.config import settings
from app.core.dependencies import get_audit_service, get_current_user, get_pdf_service, require_roles
from app.models.user import User
from app.schemas.audit import AuditLogOut
from app.schemas.pdf import (
    AllDepartmentLinkItem,
    DepartmentLinkItem,
    DocumentNameItem,
    DocumentNameSearchResponse,
    DuplicateCheckItem,
    FileUploadResponse,
    LinkDocumentRequest,
    LinkReviewRequest,
    LinkedDocumentItem,
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

_approver_roles = require_roles("approver", "admin", "super Admin")


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
    doc = service.review_document(body.pdf_id, current_user.id, body.action, body.comments, body.annotations_json)
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
    limit: int = Query(20, ge=1, le=1000),
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
    limit: int = Query(20, ge=1, le=1000),
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


@router.get(
    "/check-duplicate",
    response_model=list[DuplicateCheckItem],
    summary="Check if a document with the same name and type already exists in another department",
)
def check_duplicate_document(
    document_name: str = Query(..., min_length=1),
    document_type_id: int = Query(...),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    # Parse first dept id as int; use 0 when user has no department (SP treats all as 'other_dept')
    dept_id = int(current_user.department_id.split(',')[0]) if current_user.department_id else 0
    rows = service.check_duplicate_document(document_name, document_type_id, dept_id)
    return [
        DuplicateCheckItem(
            id=r["id"],
            document_name=r["document_name"],
            version_no=r.get("version_no"),
            status=r["status"],
            created_at=r["created_at"],
            department_id=r.get("department_id"),
            department_name=r.get("department_name"),
            document_type_name=r.get("document_type_name"),
            uploader_username=r.get("uploader_username"),
            match_type=r["match_type"],
        )
        for r in rows
    ]


@router.post(
    "/link-department",
    summary="Request to link an existing document to the caller's department",
)
def link_document_to_department(
    body: LinkDocumentRequest,
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    if not current_user.department_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="User has no department assigned")
    dept_id = int(current_user.department_id.split(',')[0])
    result = service.link_document_to_department(body.pdf_id, dept_id, current_user.id)
    return result


@router.get(
    "/linked-documents",
    response_model=list[LinkedDocumentItem],
    summary="Documents linked to caller's department (all statuses by default)",
)
def get_linked_documents(
    link_status: Optional[str] = Query(None, description="Filter by link status: pending | approved | rejected"),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    if not current_user.department_id:
        return []
    dept_id = int(current_user.department_id.split(',')[0])
    rows = service.get_linked_documents_for_department(dept_id, link_status)
    return [
        LinkedDocumentItem(
            id=r["id"],
            original_filename=r["original_filename"],
            file_path=r.get("file_path"),
            file_size=r["file_size"],
            status=r["status"],
            document_name=r.get("document_name"),
            version_no=r.get("version_no"),
            reference_number=r.get("reference_number"),
            issue_date=r.get("issue_date"),
            document_type_id=r.get("document_type_id"),
            document_type_name=r.get("document_type_name"),
            department_id=r.get("department_id"),
            department_name=r.get("department_name"),
            uploaded_by=r["uploaded_by"],
            uploader_username=r.get("uploader_username"),
            uploader_first_name=r.get("uploader_first_name"),
            uploader_last_name=r.get("uploader_last_name"),
            created_at=r["created_at"],
            link_id=r["link_id"],
            link_status=r["link_status"],
            review_comments=r.get("review_comments"),
            reviewed_at=r.get("reviewed_at"),
            link_annotations_json=r.get("link_annotations_json"),
            link_reviewed_by_username=r.get("link_reviewed_by_username"),
            link_reviewed_by_first_name=r.get("link_reviewed_by_first_name"),
            link_reviewed_by_last_name=r.get("link_reviewed_by_last_name"),
        )
        for r in rows
    ]


@router.get(
    "/department-link-requests",
    response_model=list[DepartmentLinkItem],
    summary="Approver — link requests for their department (pending by default)",
)
def get_department_link_requests(
    link_status: Optional[str] = Query("pending", description="pending | approved | rejected | null for all"),
    current_user: User = Depends(_approver_roles),
    service: PDFService = Depends(get_pdf_service),
):
    if not current_user.department_id:
        return []
    dept_id = int(current_user.department_id.split(',')[0])
    status_param = None if link_status == "all" else link_status
    rows = service.get_links_for_department(dept_id, status_param)
    return [
        DepartmentLinkItem(
            link_id=r["link_id"],
            pdf_id=r["pdf_id"],
            link_status=r["link_status"],
            requested_at=r["requested_at"],
            reviewed_at=r.get("reviewed_at"),
            review_comments=r.get("review_comments"),
            document_name=r.get("document_name"),
            version_no=r.get("version_no"),
            document_status=r["document_status"],
            document_type_name=r.get("document_type_name"),
            original_department_name=r.get("original_department_name"),
            requested_by_username=r.get("requested_by_username"),
            requested_by_first_name=r.get("requested_by_first_name"),
            requested_by_last_name=r.get("requested_by_last_name"),
            reviewed_by_username=r.get("reviewed_by_username"),
            reviewed_by_first_name=r.get("reviewed_by_first_name"),
            reviewed_by_last_name=r.get("reviewed_by_last_name"),
        )
        for r in rows
    ]


_admin_roles = require_roles("admin", "super Admin", "nodal Officer")


@router.get(
    "/all-department-links",
    response_model=list[AllDepartmentLinkItem],
    summary="Admin/Nodal — all department link requests across all departments",
)
def get_all_department_links(
    link_status: Optional[str] = Query(None, description="Filter: pending | approved | rejected (null = all)"),
    department_id: Optional[int] = Query(None, description="Filter by linked-to department id"),
    current_user: User = Depends(_admin_roles),
    service: PDFService = Depends(get_pdf_service),
):
    rows = service.get_all_department_links(link_status, department_id)
    return [
        AllDepartmentLinkItem(
            link_id=r["link_id"],
            pdf_id=r["pdf_id"],
            link_status=r["link_status"],
            requested_at=r["requested_at"],
            reviewed_at=r.get("reviewed_at"),
            review_comments=r.get("review_comments"),
            document_name=r.get("document_name"),
            version_no=r.get("version_no"),
            document_status=r["document_status"],
            document_type_name=r.get("document_type_name"),
            original_department_name=r.get("original_department_name"),
            linked_department_name=r.get("linked_department_name"),
            requested_by_username=r.get("requested_by_username"),
            requested_by_first_name=r.get("requested_by_first_name"),
            requested_by_last_name=r.get("requested_by_last_name"),
            reviewed_by_username=r.get("reviewed_by_username"),
            reviewed_by_first_name=r.get("reviewed_by_first_name"),
            reviewed_by_last_name=r.get("reviewed_by_last_name"),
        )
        for r in rows
    ]


@router.post(
    "/review-link",
    summary="Approver — approve or reject a department link request",
)
def review_department_link(
    body: LinkReviewRequest,
    current_user: User = Depends(_approver_roles),
    service: PDFService = Depends(get_pdf_service),
):
    if body.action not in ("approved", "rejected"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="action must be 'approved' or 'rejected'")
    try:
        service.review_department_link(body.link_id, body.action, current_user.id, body.comments, body.annotations_json)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    return {"ok": True, "link_id": body.link_id, "action": body.action}


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
