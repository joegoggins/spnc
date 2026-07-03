from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app_api.db import Base


class CollabSite(Base):
    """A collaborative site. SPNC-0007 starts with just a name; later stories add
    subdomain / center / radius_m and friends."""

    __tablename__ = "collab_sites"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
