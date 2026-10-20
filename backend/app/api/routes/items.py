from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.repositories.item_repository import ItemRepository
from app.schemas.item import AttachmentDownload, ItemCreate, ItemRead
from app.services.item_service import ItemService
from app.services.storage_service import StorageService

router = APIRouter(prefix="/items", tags=["items"])


def get_item_service(db: Session = Depends(get_db)) -> ItemService:
    return ItemService(ItemRepository(db))


@router.post("", response_model=ItemRead, status_code=status.HTTP_201_CREATED)
def create_item(payload: ItemCreate, service: ItemService = Depends(get_item_service)):
    return service.create(payload.name)


@router.get("/{item_id}", response_model=ItemRead)
def get_item(item_id: int, service: ItemService = Depends(get_item_service)):
    return service.get(item_id)


@router.post("/{item_id}/attachment", response_model=ItemRead)
async def upload_attachment(
    item_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    repository = ItemRepository(db)
    item = ItemService(repository).get(item_id)
    key = await StorageService().upload(item_id, file)
    return repository.set_attachment(item, key)


@router.get("/{item_id}/attachment", response_model=AttachmentDownload)
def download_attachment(item_id: int, service: ItemService = Depends(get_item_service)):
    item = service.get(item_id)
    if not item.attachment_key:
        raise HTTPException(status_code=404, detail="Attachment not found")
    return AttachmentDownload(url=StorageService().download_url(item.attachment_key))
