from fastapi import APIRouter, Depends, HTTPException, status

from app.core.dependencies import get_tag_repository, require_roles
from app.interfaces.tag_repository import ITagRepository
from app.schemas.tag import TagCreate, TagOut

router = APIRouter(prefix="/tags", tags=["Tags"])


@router.get("/", response_model=list[TagOut])
def list_tags(
    repo: ITagRepository = Depends(get_tag_repository),
):
    return repo.list_all()


@router.get("/{tag_id}", response_model=TagOut)
def get_tag(
    tag_id: int,
    repo: ITagRepository = Depends(get_tag_repository),
):
    tag = repo.get_by_id(tag_id)
    if not tag:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tag not found")
    return tag


@router.post("/", response_model=TagOut, status_code=status.HTTP_201_CREATED)
def create_tag(
    body: TagCreate,
    _=Depends(require_roles("super Admin", "admin")),
    repo: ITagRepository = Depends(get_tag_repository),
):
    try:
        return repo.create(body.name, body.parent_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
