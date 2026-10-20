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
