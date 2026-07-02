# postcard-printer

Programmatically render 4" × 6" postcards for **Avery 5389** (2-up on US Letter),
from a small YAML file to a print-ready PDF. Designs are HTML/CSS templates, so
adding a new format is just adding a template.

Ships with two card formats:

- **itinerary** — accent rail, headline, timeline list, optional QR code
- **note** — lined-paper "handwritten" note with a QR code in the corner

## How it works

`data.yaml` → Jinja2 template per card → one HTML page laid out to the exact
Avery 5389 geometry → PDF. Each Letter sheet holds 2 cards
(6"w × 4"h, left/top margins 1.25"/1.5", cards abutting).

## Setup

```bash
cd projects/postcard-printer
python3 -m venv .venv
.venv/bin/pip install jinja2 pyyaml segno
```

That's the whole install for **HTML output** and for **PDF output via Chrome**
(if Google Chrome/Chromium/Edge/Brave is installed, it's used automatically —
no native libraries needed).

For PDF via WeasyPrint instead (no browser required):

```bash
.venv/bin/pip install weasyprint    # and: brew install pango
```

## Usage

```bash
# PDF (uses WeasyPrint if installed, else a headless browser)
.venv/bin/python -m postcard_printer render examples/itinerary.yaml -o out/itinerary.pdf

# HTML — open it and print from your browser (best font fidelity)
.venv/bin/python -m postcard_printer render examples/itinerary.yaml -o out/itinerary.html

# Fill BOTH cards on the sheet with the same design
.venv/bin/python -m postcard_printer render examples/itinerary.yaml --copies 2 -o out/itinerary.pdf

# Two different formats on one sheet
.venv/bin/python -m postcard_printer render examples/mixed.yaml -o out/mixed.pdf

# Alignment test sheet (see "Calibrating" below)
.venv/bin/python -m postcard_printer calibrate -o out/calibration.pdf
```

Output extension picks the format: `.pdf` or `.html`.

## Printing (important)

1. Print **at 100% / "Actual size"** — turn OFF "Fit to page" / "Scale to fit",
   or the 6×4 cards won't line up with the die-cuts.
2. Set paper to **US Letter** and orientation **Portrait**.
3. Print a plain-paper copy first and hold it over a blank Avery sheet against a
   light to check registration before using real cards.

> Note: Avery lists 5389 as a **laser** stock. It's uncoated white cardstock, so
> inkjet generally works, but ink can sit wetter/smear more than on inkjet-coated
> stock — give prints a minute to dry and test one sheet first.

## Calibrating alignment

If cards print slightly off, nudge them with a global offset (inches;
`+x` = right, `+y` = down) and re-check with the calibration sheet:

```bash
.venv/bin/python -m postcard_printer calibrate --offset-x 0.03 --offset-y -0.05 -o out/cal.pdf
```

Once it lines up, pass the same `--offset-x/--offset-y` to `render`.

## Card data format

```yaml
cards:
  - type: itinerary
    date: "Saturday · July 12"      # small eyebrow line (optional)
    title: "A Day in Point Reyes"
    subtitle: "Pack layers."         # optional
    accent: "#2f7d5b"                # rail + time color (optional)
    items:
      - { time: "9:00a", text: "Coffee" }   # time optional; text required
      - { text: "Wander" }
    footer: "made with love"         # optional
    qr: "https://example.com/day"    # optional -> QR bottom-right

  - type: note
    title: "Hey friend,"
    text: "Longer handwritten body..."
    signoff: "— J"
    qr: "https://example.com/photos"
    qr_caption: "trip photos"
```

## Adding a new format

1. Add `templates/cards/<name>.html.j2`. It receives `card` (your dict) and
   `slot` (`slot.left_in`, `slot.top_in`); start from the `.card` wrapper in an
   existing template so positioning is handled.
2. Add matching styles in `templates/styles.css`.
3. Register it in `CARD_TEMPLATES` in [render.py](postcard_printer/render.py).
4. Use `type: <name>` in your YAML.

Handwritten fonts: the note card uses the macOS "Bradley Hand" system font via a
`cursive` fallback. For a specific web font, add an `@font-face` (with a local
file, since PDF rendering doesn't fetch the network) and print via the browser.
