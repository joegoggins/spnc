import os
from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

# In-cluster default points at the app-api-postgres Service (same-namespace short
# name resolves in both `default` locally and `sp-staging` remotely). Overridden
# via the DATABASE_URL env (the chart builds it; tests point it at SQLite through
# a dependency override, so this connection string is never used under pytest).
DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql+psycopg://collabornet:collabornet@app-api-postgres:5432/collabornet",
)

# create_engine is lazy — importing this module never opens a connection, so a
# missing/absent DB doesn't break import (or the DB-free `/` liveness route).
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_session() -> Iterator[Session]:
    """FastAPI dependency yielding one Session per request."""
    with SessionLocal() as session:
        yield session
