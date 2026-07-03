"""Seed the collab_sites table from a YAML fixture set.

Fixture sets live under fixtures/<set>/collab_sites.yaml. The `demo` set holds the
single "Demo Site" row (SPNC-0007). Seeding is idempotent — it wipes collab_sites
first — so re-running after editing a fixture reflects the change. In-cluster:

    kubectl -n <ns> exec deployment/app-api -- python -m app_api.seed --fixture-set demo
"""

import argparse
import os
from pathlib import Path

import yaml
from sqlalchemy import delete
from sqlalchemy.orm import Session

from app_api.db import SessionLocal
from app_api.models import CollabSite

# Container sets FIXTURES_DIR=/app/fixtures (fixtures are copied in, not packaged);
# for local/editable runs (tests, dev) fall back to the source tree next to app_api.
FIXTURES_DIR = Path(
    os.environ.get("FIXTURES_DIR") or Path(__file__).resolve().parent.parent / "fixtures"
)


def load_fixture_set(session: Session, fixture_set: str = "demo") -> int:
    """Replace collab_sites with the rows in fixtures/<fixture_set>/collab_sites.yaml,
    committing the result. Returns the number of rows loaded."""
    path = FIXTURES_DIR / fixture_set / "collab_sites.yaml"
    rows = yaml.safe_load(path.read_text()) or []
    session.execute(delete(CollabSite))
    session.add_all(CollabSite(name=row["name"]) for row in rows)
    session.commit()
    return len(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed collab_sites from a fixture set.")
    parser.add_argument("--fixture-set", default="demo")
    args = parser.parse_args()
    with SessionLocal() as session:
        count = load_fixture_set(session, args.fixture_set)
    print(f"seeded {count} collab_sites from fixture set '{args.fixture_set}'")


if __name__ == "__main__":
    main()
