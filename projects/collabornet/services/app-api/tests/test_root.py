from fastapi.testclient import TestClient

from app_api.main import app

client = TestClient(app)


def test_root_says_ok():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == "OK"
