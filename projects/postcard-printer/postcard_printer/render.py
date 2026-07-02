"""Render card data -> full-sheet HTML -> PDF (or HTML for browser printing)."""
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, select_autoescape

from .layout import CARDS_PER_SHEET
from .layout import slots as make_slots
from .qr import qr_svg

TEMPLATES_DIR = Path(__file__).resolve().parent.parent / "templates"

# Map a card's "type" to its template. Add a file here to add a new format.
CARD_TEMPLATES = {
    "itinerary": "cards/itinerary.html.j2",
    "note": "cards/note.html.j2",
}


def _env() -> Environment:
    return Environment(
        loader=FileSystemLoader(str(TEMPLATES_DIR)),
        autoescape=select_autoescape(["html", "xml", "j2"]),
    )


def _prepare(cards: list[dict]) -> list[dict]:
    """Copy each card and pre-render any QR payload into an inline SVG."""
    prepared = []
    for card in cards:
        c = dict(card)
        if c.get("qr"):
            c["qr_svg"] = qr_svg(c["qr"])
        prepared.append(c)
    return prepared


def _chunk(seq, n):
    for i in range(0, len(seq), n):
        yield seq[i : i + n]


def build_html(cards: list[dict], offset_x_in: float = 0.0, offset_y_in: float = 0.0) -> str:
    env = _env()
    css = (TEMPLATES_DIR / "styles.css").read_text()
    slot_list = make_slots(offset_x_in, offset_y_in)
    prepared = _prepare(cards)

    pages = []
    for chunk in _chunk(prepared, CARDS_PER_SHEET):
        fragments = []
        for card, slot in zip(chunk, slot_list):
            tmpl_name = CARD_TEMPLATES.get(card.get("type", "itinerary"))
            if not tmpl_name:
                raise ValueError(f"Unknown card type: {card.get('type')!r}")
            fragments.append(env.get_template(tmpl_name).render(card=card, slot=slot))
        pages.append(fragments)

    return env.get_template("sheet.html.j2").render(pages=pages, css=css)


def build_calibration_html(offset_x_in: float = 0.0, offset_y_in: float = 0.0) -> str:
    env = _env()
    css = (TEMPLATES_DIR / "styles.css").read_text()
    slot_list = make_slots(offset_x_in, offset_y_in)
    return env.get_template("calibration.html.j2").render(
        slots=slot_list, css=css, offset_x=offset_x_in, offset_y=offset_y_in
    )


# Headless-browser fallback for PDF output when WeasyPrint isn't installed.
_CHROME_APPS = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
]


def _find_chrome() -> str | None:
    for name in ("google-chrome", "chromium", "chromium-browser", "chrome"):
        if (found := shutil.which(name)):
            return found
    for app in _CHROME_APPS:
        if os.path.exists(app):
            return app
    return None


def _pdf_via_chrome(chrome: str, html: str, out_path: str) -> None:
    # Everything (CSS + QR SVG) is inlined, so the temp file location is irrelevant.
    tmp = tempfile.NamedTemporaryFile("w", suffix=".html", delete=False)
    try:
        tmp.write(html)
        tmp.close()
        subprocess.run(
            [chrome, "--headless", "--disable-gpu", "--no-pdf-header-footer",
             f"--print-to-pdf={os.path.abspath(out_path)}", f"file://{tmp.name}"],
            check=True, capture_output=True,
        )
    finally:
        os.unlink(tmp.name)


def _html_to_pdf(html: str, out_path: str) -> None:
    """PDF via WeasyPrint if available, else a headless Chromium-family browser."""
    try:
        from weasyprint import HTML
    except Exception as weasy_err:  # ImportError or missing native libs (pango)
        chrome = _find_chrome()
        if not chrome:
            raise RuntimeError(
                f"No PDF backend available ({weasy_err}).\n"
                "  Option A:  pip install weasyprint   and   brew install pango\n"
                "  Option B:  install Google Chrome (used automatically), or\n"
                "  Option C:  render to a .html file and print from your browser at 100%."
            ) from weasy_err
        _pdf_via_chrome(chrome, html, out_path)
        return
    HTML(string=html, base_url=str(TEMPLATES_DIR)).write_pdf(out_path)


def write_output(html: str, out_path: str) -> Path:
    out = Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    suffix = out.suffix.lower()
    if suffix == ".pdf":
        _html_to_pdf(html, str(out))
    elif suffix in (".html", ".htm"):
        out.write_text(html)
    else:
        raise ValueError("Output path must end in .pdf or .html")
    return out
