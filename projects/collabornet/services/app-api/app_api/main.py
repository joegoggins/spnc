from fastapi import Depends, FastAPI
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select
from sqlalchemy.orm import Session

from app_api.db import get_session
from app_api.models import CollabSite

app = FastAPI(title="Collabornet API")


class CollabSiteOut(BaseModel):
    """API shape of a collab site. Per SPNC-0007 the demo dataset only has a name."""

    model_config = ConfigDict(from_attributes=True)

    name: str


@app.get("/")
def read_root() -> str:
    """Liveness/readiness sentinel. DB-free on purpose, so probes pass before
    migrations have run. Per SPNC-0007 the root route just says OK."""
    return "OK"


@app.get("/sites")
def list_sites(session: Session = Depends(get_session)) -> list[CollabSiteOut]:
    """List the rows in the collab_sites table."""
    return list(session.scalars(select(CollabSite).order_by(CollabSite.name)))
