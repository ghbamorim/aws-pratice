from uuid import uuid4

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from fastapi import HTTPException, UploadFile

from app.core.config import settings

MAX_FILE_SIZE = 5 * 1024 * 1024
ALLOWED_TYPES = {"application/pdf", "image/png", "image/jpeg"}


class StorageService:
    def __init__(self):
        if not settings.s3_bucket:
            raise HTTPException(status_code=503, detail="S3 bucket is not configured")
        self.client = boto3.client("s3", region_name=settings.aws_region)

    async def upload(self, item_id: int, file: UploadFile) -> str:
        if file.content_type not in ALLOWED_TYPES:
            raise HTTPException(status_code=415, detail="Only PDF, PNG and JPEG are allowed")
        data = await file.read(MAX_FILE_SIZE + 1)
        if len(data) > MAX_FILE_SIZE:
            raise HTTPException(status_code=413, detail="File exceeds 5 MiB")
        key = f"items/{item_id}/{uuid4()}"
        try:
            self.client.put_object(
                Bucket=settings.s3_bucket, Key=key, Body=data, ContentType=file.content_type
            )
        except (BotoCoreError, ClientError) as exc:
            raise HTTPException(status_code=502, detail="S3 upload failed") from exc
        return key

    def download_url(self, key: str) -> str:
        try:
            return self.client.generate_presigned_url(
                "get_object", Params={"Bucket": settings.s3_bucket, "Key": key}, ExpiresIn=300
            )
        except (BotoCoreError, ClientError) as exc:
            raise HTTPException(status_code=502, detail="S3 link generation failed") from exc
