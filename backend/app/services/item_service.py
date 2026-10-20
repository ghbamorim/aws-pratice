from fastapi import HTTPException, status

from app.models.item import Item
from app.repositories.item_repository import ItemRepository


class ItemService:
    def __init__(self, repository: ItemRepository):
        self.repository = repository

    def create(self, name: str) -> Item:
        return self.repository.create(name=name)

    def get(self, item_id: int) -> Item:
        item = self.repository.get(item_id)
        if item is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
        return item
