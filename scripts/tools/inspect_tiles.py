#!/usr/bin/env python3
"""Inspect the zeldalike_overworld tileset and print a coordinate legend.

Samples each 16x16 cell, prints average color and groups visually similar
regions so we can pick srcIds for LDtk tile layers.
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import List, Tuple

from PIL import Image


def rgb_to_hex(rgb: Tuple[int, int, int]) -> str:
    return "#%02x%02x%02x" % rgb


def cell_color(img: Image.Image, col: int, row: int, size: int = 16) -> Tuple[int, int, int]:
    """Return the average opaque RGB color of a tile cell."""
    left = col * size
    top = row * size
    pixels: List[Tuple[int, int, int, int]] = []
    for y in range(top, top + size):
        for x in range(left, left + size):
            pixels.append(img.getpixel((x, y)))

    opaque = [p for p in pixels if len(p) < 4 or p[3] > 0]
    if not opaque:
        opaque = pixels

    r = sum(p[0] for p in opaque) // len(opaque)
    g = sum(p[1] for p in opaque) // len(opaque)
    b = sum(p[2] for p in opaque) // len(opaque)
    return (r, g, b)


def bucket_key(rgb: Tuple[int, int, int], step: int = 32) -> Tuple[int, int, int]:
    return (rgb[0] // step, rgb[1] // step, rgb[2] // step)


def main() -> int:
    tileset_path = Path(__file__).resolve().parents[2] / "art" / "tilesets" / "zeldalike_overworld.png"
    if not tileset_path.exists():
        print(f"Tileset not found: {tileset_path}", file=sys.stderr)
        return 1

    img = Image.open(tileset_path).convert("RGBA")
    width, height = img.size
    tile_size = 16
    cols = width // tile_size
    rows = height // tile_size

    print(f"Tileset: {tileset_path.name} ({width}x{height} => {cols} cols x {rows} rows)")
    print(f"srcId = row * {cols} + col (0-based)")
    print()

    buckets: dict[Tuple[int, int, int], List[Tuple[Tuple[int, int, int], int, int, int]]] = {}
    for row in range(rows):
        for col in range(cols):
            rgb = cell_color(img, col, row, tile_size)
            src_id = row * cols + col
            key = bucket_key(rgb)
            buckets.setdefault(key, []).append((rgb, src_id, col, row))

    for key, cells in sorted(buckets.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        label = rgb_to_hex((key[0] * 32 + 16, key[1] * 32 + 16, key[2] * 32 + 16))
        print(f"Color bucket {label} ({len(cells)} cells):")
        for rgb, src_id, col, row in sorted(cells, key=lambda c: c[1]):
            print(f"  srcId={src_id:4d} (col={col:2d},row={row:2d}) avg={rgb_to_hex(rgb)}")
        print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
