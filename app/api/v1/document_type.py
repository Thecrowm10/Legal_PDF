from fastapi import APIRouter, Depends, HTTPException, status

from app.core.dependencies import get_document_type_repository, require_roles
from app.interfaces.document_type_repository import IDocumentTypeRepository
from app.schemas.document_type import DocumentTypeCreate, DocumentTypeOut

router = APIRouter(prefix="/document-types", tags=["Document Types"])


@router.get("/", response_model=list[DocumentTypeOut])
def list_document_types(
    repo: IDocumentTypeRepository = Depends(get_document_type_repository),
):
    return repo.list_all()


@router.get("/{type_id}", response_model=DocumentTypeOut)
def get_document_type(
    type_id: int,
    repo: IDocumentTypeRepository = Depends(get_document_type_repository),
):
    doc_type = repo.get_by_id(type_id)
    if not doc_type:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document type not found")
    return doc_type


@router.post("/", response_model=DocumentTypeOut, status_code=status.HTTP_201_CREATED)
def create_document_type(
    body: DocumentTypeCreate,
    _=Depends(require_roles("super Admin", "admin")),
    repo: IDocumentTypeRepository = Depends(get_document_type_repository),
):
    try:
        return repo.create(body.name, body.description)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
