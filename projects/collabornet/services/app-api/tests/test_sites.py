def test_sites_lists_demo_site(client_for):
    response = client_for("demo").get("/sites")
    assert response.status_code == 200
    assert [site["name"] for site in response.json()] == ["Demo Site"]
