#!/usr/bin/env python3
"""Import the approved CC0 art packs used by the opening presentation."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path


OPENRTP_SOURCE_ROOT = Path("/Users/spkoehl/Downloads/openRPG_Tilesets_5.24.22")
DOWNLOAD_DATE = "2026-08-26"

SOURCES = {
    "openrtp": ["world.png", "exterior.png", "interior.png", "dungeon.png", "ship.png", "ReadMe.txt"],
    "gloomy_fantasy": ["Pixel Fantasy Tileset.png"],
    "frontier_wagons": ["frontier_wagons.png"],
    "kenney_rpg_urban": ["Tilemap/tilemap_packed.png", "License.txt"],
}

PACKS = {
    "openrtp": {
        "creator": "finalbossblues",
        "destination": Path("art/tilesets/openrtp"),
        "source_url": "https://finalbossblues.itch.io/openrtp-tiles",
    },
    "gloomy_fantasy": {
        "creator": "Loota",
        "destination": Path("art/tilesets/gloomy_fantasy"),
        "source_url": "https://loota9.itch.io/pixel-fantasy-tileset",
        "source_archive": "Pixel Fantasy Tileset.rar",
        "source_path_in_archive": "Assets/tiles.png",
    },
    "frontier_wagons": {
        "creator": "zwonky",
        "destination": Path("art/props/frontier_wagons"),
        "source_url": "https://opengameart.org/content/frontier-wagons",
    },
    "kenney_rpg_urban": {
        "creator": "Kenney",
        "destination": Path("art/tilesets/kenney_rpg_urban"),
        "source_url": "https://kenney.nl/assets/rpg-urban-pack",
    },
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source_file:
        for block in iter(lambda: source_file.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def source_path(source_root: Path, pack_id: str, relative_path: str) -> Path:
    if pack_id == "openrtp":
        return OPENRTP_SOURCE_ROOT / relative_path
    return source_root / pack_id / relative_path


def provenance(pack_id: str, files: list[str], hashes: dict[str, str]) -> dict[str, object]:
    pack = PACKS[pack_id]
    record: dict[str, object] = {
        "pack_id": pack_id,
        "creator": pack["creator"],
        "source_url": pack["source_url"],
        "license": "CC0-1.0",
        "downloaded_at": DOWNLOAD_DATE,
        "files": files,
        "sha256": hashes,
    }
    for key in ("source_archive", "source_path_in_archive"):
        if key in pack:
            record[key] = pack[key]
    return record


def import_art(source_root: Path, project_root: Path) -> int:
    missing = [
        source_path(source_root, pack_id, relative_path)
        for pack_id, paths in SOURCES.items()
        for relative_path in paths
        if not source_path(source_root, pack_id, relative_path).is_file()
    ]
    if missing:
        for path in missing:
            print(f"MISSING: {path}")
        return 1

    for pack_id, paths in SOURCES.items():
        destination_root = project_root / PACKS[pack_id]["destination"]
        hashes: dict[str, str] = {}
        for relative_path in paths:
            source = source_path(source_root, pack_id, relative_path)
            destination = destination_root / relative_path
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
            source_hash = sha256(source)
            if sha256(destination) != source_hash:
                print(f"CHECKSUM ERROR: {destination}")
                return 1
            hashes[relative_path] = source_hash

        record_path = destination_root / "PROVENANCE.json"
        record_path.write_text(
            json.dumps(provenance(pack_id, paths, hashes), indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        print(f"IMPORTED: {pack_id}")

    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-root",
        required=True,
        type=Path,
        help="Directory containing the official creator-download staging folders.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    project_root = Path(__file__).resolve().parent.parent
    return import_art(args.source_root, project_root)


if __name__ == "__main__":
    sys.exit(main())
