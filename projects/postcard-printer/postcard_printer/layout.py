"""Sheet geometry for Avery 5389 postcards (4" x 6", 2 per US Letter sheet).

The two cards are landscape (6" wide x 4" tall), centered horizontally,
stacked vertically and abutting, and centered top-to-bottom. All values are
derived from the sheet/card sizes so there is a single source of truth.
"""
from __future__ import annotations

from dataclasses import dataclass

SHEET_W_IN = 8.5
SHEET_H_IN = 11.0
CARD_W_IN = 6.0
CARD_H_IN = 4.0
CARDS_PER_SHEET = 2

LEFT_MARGIN_IN = (SHEET_W_IN - CARD_W_IN) / 2  # 1.25"
TOP_MARGIN_IN = (SHEET_H_IN - CARD_H_IN * CARDS_PER_SHEET) / 2  # 1.5"


@dataclass(frozen=True)
class Slot:
    """Top-left position of a card on the sheet, in inches."""

    left_in: float
    top_in: float


def slots(offset_x_in: float = 0.0, offset_y_in: float = 0.0) -> list[Slot]:
    """Card positions, nudged by a global print offset for alignment tuning."""
    return [
        Slot(
            round(LEFT_MARGIN_IN + offset_x_in, 4),
            round(TOP_MARGIN_IN + i * CARD_H_IN + offset_y_in, 4),
        )
        for i in range(CARDS_PER_SHEET)
    ]
