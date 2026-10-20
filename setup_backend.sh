#!/usr/bin/env bash
set -euo pipefail
if [[ ! -d .git ]]; then echo 'Execute na raiz do repositorio Git.' >&2; exit 1; fi
if [[ -e backend/pyproject.toml || -e backend/app/main.py || -e compose.yaml ]]; then echo 'Arquivos do backend ou compose.yaml ja existem; script interrompido para evitar sobrescrita.' >&2; exit 1; fi
mkdir -p backend/app/{api/routes,core,db,models,repositories,schemas,services} backend/alembic/versions backend/tests
for dir in backend/app backend/app/api backend/app/api/routes backend/app/core backend/app/db backend/app/models backend/app/repositories backend/app/schemas backend/app/services; do touch "$dir/__init__.py"; done
cat > backend/pyproject.toml <<'EOF'
[project]
name = "fullstack-lab-backend"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
  "fastapi>=0.115,<1",
  "uvicorn[standard]>=0.30,<1",
  "sqlalchemy>=2.0,<3",
  "psycopg[binary]>=3.2,<4",
  "pydantic-settings>=2.5,<3",
  "alembic>=1.13,<2",
  "boto3>=1.35,<2",
  "python-multipart>=0.0.9,<1",
]
[project.optional-dependencies]
dev = ["pytest>=8,<10", "httpx>=0.27,<1", "ruff>=0.8,<1"]
[tool.ruff]
line-length = 100
[tool.pytest.ini_options]
testpaths = ["tests"]
EOF
cat > backend/app/core/config.py <<'EOF'
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://app:app@localhost:5432/app"
    aws_region: str = "us-east-2"
    s3_bucket: str = ""
    cors_origins: list[str] = ["http://localhost:5173"]

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
EOF
cat > backend/app/db/session.py <<'EOF'
from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings

engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_db() -> Generator[Session, None, None]:
    with SessionLocal() as session:
        yield session
EOF
cat > backend/app/db/base.py <<'EOF'
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass
EOF
cat > backend/app/models/item.py <<'EOF'
from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Item(Base):
    __tablename__ = "items"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    attachment_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
EOF
cat > backend/app/schemas/item.py <<'EOF'
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
EOF
cat > backend/app/repositories/item_repository.py <<'EOF'
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
EOF
cat > backend/app/services/item_service.py <<'EOF'
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
EOF
cat > backend/app/services/storage_service.py <<'EOF'
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
EOF
cat > backend/app/api/routes/items.py <<'EOF'
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
EOF
cat > backend/app/main.py <<'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes.items import router as items_router
from app.core.config import settings

app = FastAPI(title="Fullstack Lab API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)
app.include_router(items_router, prefix="/api")


@app.get("/health", tags=["health"])
def health():
    return {"status": "ok"}
EOF
cat > backend/alembic.ini <<'EOF'
[alembic]
script_location = alembic
prepend_sys_path = .

[loggers]
keys = root,sqlalchemy,alembic
[handlers]
keys = console
[formatters]
keys = generic
[logger_root]
level = WARNING
handlers = console
[logger_sqlalchemy]
level = WARNING
handlers =
qualname = sqlalchemy.engine
[logger_alembic]
level = INFO
handlers =
qualname = alembic
[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic
[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
EOF
cat > backend/alembic/env.py <<'EOF'
from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

from app.core.config import settings
from app.db.base import Base
from app.models.item import Item  # noqa: F401 - registers model in metadata

config = context.config
config.set_main_option("sqlalchemy.url", settings.database_url.replace("%", "%%"))
if config.config_file_name:
    fileConfig(config.config_file_name)
target_metadata = Base.metadata


def run_migrations_offline():
    context.configure(url=settings.database_url, target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online():
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}), prefix="sqlalchemy.", poolclass=pool.NullPool
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
EOF
cat > backend/alembic/script.py.mako <<'EOF'
"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
${imports if imports else ""}
revision: str = ${repr(up_revision)}
down_revision: Union[str, None] = ${repr(down_revision)}
branch_labels: Union[str, Sequence[str], None] = ${repr(branch_labels)}
depends_on: Union[str, Sequence[str], None] = ${repr(depends_on)}

def upgrade() -> None:
    ${upgrades if upgrades else "pass"}

def downgrade() -> None:
    ${downgrades if downgrades else "pass"}
EOF
cat > backend/alembic/versions/0001_create_items.py <<'EOF'
"""create items table

Revision ID: 0001
Revises:
"""
from alembic import op
import sqlalchemy as sa

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "items",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("attachment_key", sa.String(length=512), nullable=True),
    )


def downgrade():
    op.drop_table("items")
EOF
cat > backend/tests/test_health.py <<'EOF'
from fastapi.testclient import TestClient

from app.main import app


def test_health():
    response = TestClient(app).get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
EOF
cat > backend/tests/test_items.py <<'EOF'
from unittest.mock import Mock

from fastapi.testclient import TestClient

from app.api.routes.items import get_item_service
from app.main import app


def test_create_item():
    service = Mock()
    service.create.return_value = {"id": 1, "name": "Example", "attachment_key": None}
    app.dependency_overrides[get_item_service] = lambda: service
    try:
        response = TestClient(app).post("/api/items", json={"name": "Example"})
        assert response.status_code == 201
        assert response.json()["id"] == 1
        service.create.assert_called_once_with("Example")
    finally:
        app.dependency_overrides.clear()


def test_reject_empty_name():
    response = TestClient(app).post("/api/items", json={"name": ""})
    assert response.status_code == 422
EOF
cat > backend/Dockerfile <<'EOF'
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /code
COPY pyproject.toml ./
RUN pip install --no-cache-dir .
COPY app ./app
COPY alembic ./alembic
COPY alembic.ini ./
RUN useradd --create-home appuser
USER appuser
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
cat > backend/.dockerignore <<'EOF'
.env
.venv
__pycache__
.pytest_cache
.ruff_cache
*.pyc
EOF
cat > backend/.env.example <<'EOF'
DATABASE_URL=postgresql+psycopg://app:app@localhost:5432/app
AWS_REGION=us-east-2
S3_BUCKET=
EOF
cat > compose.yaml <<'EOF'
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app
      POSTGRES_DB: app
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d app"]
      interval: 5s
      timeout: 3s
      retries: 10
  api:
    build: ./backend
    environment:
      DATABASE_URL: postgresql+psycopg://app:app@db:5432/app
      AWS_REGION: us-east-2
      S3_BUCKET: ""
    ports:
      - "8000:8000"
    depends_on:
      db:
        condition: service_healthy
volumes:
  postgres_data:
EOF
cat > .gitignore <<'EOF'
.env
.env.*
!.env.example
__pycache__/
*.py[cod]
.pytest_cache/
.ruff_cache/
.venv/
node_modules/
dist/
.terraform/
*.tfstate
*.tfstate.*
EOF
cat > backend/README.md <<'EOF'
# Fullstack Lab - API

FastAPI + SQLAlchemy + Alembic + PostgreSQL + S3.

Na raiz do repositorio:

```bash
docker compose up -d --build
docker compose exec api alembic upgrade head
```

Abra http://localhost:8000/docs para testar os endpoints.

Exemplo:

```bash
curl -X POST http://localhost:8000/api/items -H 'Content-Type: application/json' -d '{"name":"Meu item"}'
curl http://localhost:8000/api/items/1
```

S3 requer S3_BUCKET e credenciais AWS por role no ECS; os endpoints de anexos retornam 503 enquanto o bucket nao estiver configurado.

Nao use a senha de desenvolvimento do Compose em producao.
EOF
printf '\nEstrutura do backend criada com sucesso.\n'
