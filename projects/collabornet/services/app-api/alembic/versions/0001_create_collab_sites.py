"""create collab_sites

Revision ID: 0001_create_collab_sites
Revises:
Create Date: 2026-07-02

Initial schema for SPNC-0007: collab_sites with just a name (plus the conventional
surrogate id PK). Later stories add subdomain / center / radius_m columns.
"""

import sqlalchemy as sa
from alembic import op

revision = "0001_create_collab_sites"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "collab_sites",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("collab_sites")
