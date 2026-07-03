from collections.abc import Callable, Iterator

import app_api.models  # noqa: F401 — register tables on Base.metadata
import pytest
from app_api.db import Base, get_session
from app_api.main import app
from app_api.seed import load_fixture_set
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool


@pytest.fixture
def client_for() -> Iterator[Callable[[str], TestClient]]:
    """Factory: build a TestClient backed by a fresh in-memory SQLite DB seeded
    from a named fixture set. Parametrizing the set lets future tests validate
    other datasets with no extra plumbing (SPNC-0007). Kept hermetic (SQLite, no
    Docker) so `make test` runs anywhere; the schema mirrors the alembic migration."""

    def _build(fixture_set: str = "demo") -> TestClient:
        engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,  # single shared connection -> in-memory DB persists
        )
        testing_session = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
        Base.metadata.create_all(engine)
        with testing_session() as session:
            load_fixture_set(session, fixture_set)

        def _get_session() -> Iterator[Session]:
            with testing_session() as session:
                yield session

        app.dependency_overrides[get_session] = _get_session
        return TestClient(app)

    yield _build
    app.dependency_overrides.clear()
