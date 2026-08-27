#!/usr/bin/env python3
"""Build deterministic, source-backed sprites for the caravan presentation."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image


WAGON_SOURCE = Path("art/props/frontier_wagons/frontier_wagons.png")
OPENRTP_SOURCE = Path("art/tilesets/openrtp/derived/exterior_transparent.png")
OUTPUT_ROOT = Path("art/generated/opening_art")

# Rectangles use source-pixel coordinates: (left, top, right, bottom).
REGIONS = {
    "wagon_a": (0, 0, 48, 32),
    "wagon_b": (96, 0, 144, 32),
    "cargo_crate": (432, 48, 448, 64),
    "cargo_barrel": (432, 80, 448, 96),
    "campfire": (336, 192, 352, 224),
    "tent_shadow": (448, 208, 480, 256),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source_file:
        for block in iter(lambda: source_file.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_png(path: Path) -> Image.Image:
    if not path.is_file():
        raise FileNotFoundError(f"missing source PNG: {path}")
    with Image.open(path) as source:
        if source.format != "PNG":
            raise ValueError(f"source is not a PNG: {path}")
        return source.convert("RGBA")


def crop_region(source: Image.Image, name: str) -> Image.Image:
    region = REGIONS[name]
    left, top, right, bottom = region
    if left < 0 or top < 0 or right <= left or bottom <= top:
        raise ValueError(f"invalid source region '{name}': {region}")
    if right > source.width or bottom > source.height:
        raise ValueError(
            f"source region '{name}' {region} exceeds {source.width}x{source.height} atlas"
        )
    return source.crop(region)


def save_png(image: Image.Image, path: Path) -> None:
    image.save(path, format="PNG", optimize=False, compress_level=9)


def composite_wagon(
    wagon_source: Image.Image,
    openrtp_source: Image.Image,
    wagon_region: str,
    cargo_region: str,
) -> Image.Image:
    canvas = Image.new("RGBA", (64, 40), (0, 0, 0, 0))
    canvas.alpha_composite(crop_region(wagon_source, wagon_region), (0, 0))
    canvas.alpha_composite(crop_region(openrtp_source, cargo_region), (44, 23))
    return canvas


def build(project_root: Path) -> None:
    wagon_path = project_root / WAGON_SOURCE
    openrtp_path = project_root / OPENRTP_SOURCE
    wagon_source = load_png(wagon_path)
    openrtp_source = load_png(openrtp_path)
    output_root = project_root / OUTPUT_ROOT
    output_root.mkdir(parents=True, exist_ok=True)

    outputs = {
        "caravan_wagon_a.png": composite_wagon(
            wagon_source, openrtp_source, "wagon_a", "cargo_crate"
        ),
        "caravan_wagon_b.png": composite_wagon(
            wagon_source, openrtp_source, "wagon_b", "cargo_barrel"
        ),
        "campfire.png": crop_region(openrtp_source, "campfire"),
        "tent_shadow.png": crop_region(openrtp_source, "tent_shadow"),
    }
    for filename, image in outputs.items():
        save_png(image, output_root / filename)

    provenance = {
        "generated_by": "tools/build_opening_art.py",
        "license": "CC0-1.0",
        "sources": {
            str(WAGON_SOURCE): sha256(wagon_path),
            str(OPENRTP_SOURCE): sha256(openrtp_path),
        },
        "regions": {name: list(region) for name, region in REGIONS.items()},
        "outputs": {
            filename: sha256(output_root / filename) for filename in sorted(outputs)
        },
    }
    (output_root / "PROVENANCE.json").write_text(
        json.dumps(provenance, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="Project root containing the documented source art.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        build(args.project_root.resolve())
    except (FileNotFoundError, OSError, ValueError) as error:
        print(f"OPENING ART BUILD ERROR: {error}", file=sys.stderr)
        return 1
    print(f"OPENING ART BUILD: PASS ({OUTPUT_ROOT})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
