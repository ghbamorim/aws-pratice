from sqlalchemy.orm import Session

from app.models.item import Item


class ItemRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(self, name: str) -> Item:
        item = Item(name=name)
        self.db.add(item)
        self.db.commit()
        self.db.refresh(item)
        return item

    def get(self, item_id: int) -> Item | None:
        return self.db.get(Item, item_id)

    def set_attachment(self, item: Item, key: str) -> Item:
        item.attachment_key = key
        self.db.commit()
        self.db.refresh(item)
        return item
