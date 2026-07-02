"""Command line: render postcards or an alignment calibration sheet."""
from __future__ import annotations

import argparse
from pathlib import Path

import yaml

from .render import build_calibration_html, build_html, write_output


def _load_cards(path: str) -> list[dict]:
    data = yaml.safe_load(Path(path).read_text())
    if isinstance(data, dict) and "cards" in data:
        return data["cards"]
    if isinstance(data, list):
        return data
    raise ValueError("Data file must be a list of cards or a mapping with a 'cards' key.")


def main(argv=None) -> None:
    p = argparse.ArgumentParser(
        prog="postcard_printer",
        description="Render 4x6 postcards for Avery 5389 (2-up on US Letter).",
    )
    sub = p.add_subparsers(dest="cmd", required=True)

    r = sub.add_parser("render", help="Render cards from a YAML/JSON data file")
    r.add_argument("data", help="Path to a .yaml/.json card file")
    r.add_argument("-o", "--out", default="out/postcards.pdf", help=".pdf or .html")
    r.add_argument("--offset-x", type=float, default=0.0, help="Print offset inches (+right)")
    r.add_argument("--offset-y", type=float, default=0.0, help="Print offset inches (+down)")
    r.add_argument("--copies", type=int, default=1, help="Repeat the whole card set N times")

    c = sub.add_parser("calibrate", help="Render an alignment test sheet (no data needed)")
    c.add_argument("-o", "--out", default="out/calibration.pdf", help=".pdf or .html")
    c.add_argument("--offset-x", type=float, default=0.0)
    c.add_argument("--offset-y", type=float, default=0.0)

    args = p.parse_args(argv)

    if args.cmd == "render":
        cards = _load_cards(args.data) * args.copies
        html = build_html(cards, args.offset_x, args.offset_y)
        out = write_output(html, args.out)
        print(f"Wrote {len(cards)} card(s) -> {out}")
    elif args.cmd == "calibrate":
        html = build_calibration_html(args.offset_x, args.offset_y)
        out = write_output(html, args.out)
        print(f"Wrote calibration sheet -> {out}")


if __name__ == "__main__":
    main()
