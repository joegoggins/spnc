from fastapi.testclient import TestClient

from app_api.main import app

client = TestClient(app)


def test_sites_lists_demo_site():
    response = client.get("/sites")
    assert response.status_code == 200
    names = [site["name"] for site in response.json()]
    assert "Demo Site" in names
