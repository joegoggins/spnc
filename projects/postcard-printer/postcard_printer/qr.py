"""QR code generation as inline SVG (pure Python, no native deps)."""
from __future__ import annotations

import io

import segno


def qr_svg(data: str, border: int = 1, dark: str = "#1a1a1a") -> str:
    """Return an inline <svg> string with no fixed size (scales to its container).

    Uses error-correction level 'M' so a small quiet zone / minor print
    imperfections still scan.
    """
    out = io.BytesIO()
    segno.make(str(data), error="m").save(
        out,
        kind="svg",
        border=border,
        dark=dark,
        xmldecl=False,   # inline, so drop the <?xml?> prolog
        svgns=True,
        omitsize=True,   # no width/height attrs -> CSS controls size via viewBox
        svgclass=None,
        lineclass=None,
    )
    return out.getvalue().decode("utf-8")
