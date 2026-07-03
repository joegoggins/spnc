def test_root_says_ok(client_for):
    response = client_for().get("/")
    assert response.status_code == 200
    assert response.json() == "OK"
