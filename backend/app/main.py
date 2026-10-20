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
