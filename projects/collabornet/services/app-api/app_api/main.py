from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="Collabornet API")


class CollabSite(BaseModel):
    name: str


# In-memory stand-in for the collab_sites table until app-api-postgres + alembic
# land (SPNC-0007). Mirrors the single "Demo Site" row that fixtures/demo will seed.
_DEMO_SITES = [CollabSite(name="Demo Site")]


@app.get("/")
def read_root() -> str:
    """Liveness/readiness sentinel. Per SPNC-0007, the root route just says OK."""
    return "OK"


@app.get("/sites")
def list_sites() -> list[CollabSite]:
    """List collab sites. In-memory for now; swaps to a DB read without changing this contract."""
    return _DEMO_SITES
