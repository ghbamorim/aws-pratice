from pydantic import BaseModel, ConfigDict, Field


class ItemCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)


class ItemRead(BaseModel):
    id: int
    name: str
    attachment_key: str | None = None

    model_config = ConfigDict(from_attributes=True)


class AttachmentDownload(BaseModel):
    url: str
