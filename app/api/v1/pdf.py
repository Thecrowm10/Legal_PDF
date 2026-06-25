from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status

from app.core.dependencies import get_current_user, get_pdf_service
from app.models.user import User
from app.schemas.pdf import (
    FileUploadResponse,
    PDFCreateRequest,
    PDFListItem,
    PDFUploadResponse,
    SearchResponse,
    SearchResultItem,
)
from app.services.pdf_service import PDFService

router = APIRouter(prefix="/pdf", tags=["PDF Documents"])

ALLOWED_CONTENT_TYPES = {"application/pdf"}


@router.post(
    "/upload-file",
    response_model=FileUploadResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Step 1 — Upload the PDF file, get back a file_ref",
)
async def upload_file(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only PDF files are allowed",
        )
    return await service.store_file(file)


@router.post(
    "/upload",
    response_model=PDFUploadResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Step 2 — Submit metadata with the file_ref from Step 1",
)
def create_document(
    body: PDFCreateRequest,
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    try:
        return service.create_from_ref(
            file_ref=body.file_ref,
            user_id=current_user.id,
            act_name=body.act_name,
            gazette_reference=body.gazette_reference,
            issuing_authority=body.issuing_authority,
            enactment_date=body.enactment_date,
            version_no=body.version_no,
            department_id=body.department_id,
            document_type_id=body.document_type_id,
            tag_ids=body.tag_ids,
            description=body.description,
        )
    except FileNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


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


@router.get("/my-documents", response_model=list[PDFListItem])
def list_my_documents(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    return service.list_my_documents(current_user.id, skip, limit)


@router.get("/all", response_model=list[PDFListItem])
def list_all_documents(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    return service.list_all_documents(skip, limit)
