#!/usr/bin/env python3
"""Deterministically rebuild the opening LDtk tile layers from OpenRTP."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import struct
import sys
import tempfile
import zlib
from copy import deepcopy
from pathlib import Path
from typing import Any


TILE_SIZE = 16
WORLD_TILESET_UID = 20
EXTERIOR_TILESET_UID = 23
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
CHROMA_RGB = (255, 103, 139)
DERIVED_EXTERIOR_PATH = Path("art/tilesets/openrtp/derived/exterior_transparent.png")
DERIVED_PROVENANCE_PATH = Path("art/tilesets/openrtp/derived/PROVENANCE.json")
PROPS_TILESET_REL_PATH = "../art/tilesets/openrtp/derived/exterior_transparent.png"

ATLAS_PATHS = {
    "world": Path("art/tilesets/openrtp/world.png"),
    "exterior": Path("art/tilesets/openrtp/exterior.png"),
}

# Every source reference is an explicit (column, row) coordinate on a 16 px
# OpenRTP atlas. Map recipes below refer only to these names.
ATLAS_TILES = {
    "world": {
        "grass_a": (0, 8),
        "grass_b": (1, 8),
        "grass_c": (2, 9),
        "grass_d": (4, 10),
        "dirt_top": (7, 0),
        "dirt_center": (7, 1),
        "dirt_bottom": (7, 2),
    },
    "exterior": {
        "tree_top": (20, 8),
        "tree_bottom": (20, 9),
        "large_tree_top_left": (22, 8),
        "large_tree_top_right": (23, 8),
        "large_tree_bottom_left": (22, 9),
        "large_tree_bottom_right": (23, 9),
        "wildflowers": (18, 11),
        "fence_left": (18, 12),
        "fence_middle": (19, 12),
        "fence_right": (20, 12),
        "campfire": (21, 12),
        "tent_top_left": (24, 11),
        "tent_top_right": (25, 11),
        "tent_bottom_left": (24, 12),
        "tent_bottom_right": (25, 12),
        "crate": (27, 3),
        "bedroll": (27, 7),
        "rock": (29, 3),
    },
}

RECIPES = {
    "caravan_route": {
        "ground": "meadow_road",
        "props": ["tree_border", "wildflowers", "fence", "camp_tent", "crate"],
        "size": (20, 15),
        "expand_gameplay": False,
    },
    "forest_campsite": {
        "ground": "campsite_expanded",
        "props": [
            "dense_tree_border",
            "lesson_grove",
            "south_trail",
            "fire_ring",
            "bedroll",
            "camp_tent",
            "crate",
        ],
        "size": (40, 28),
        "expand_gameplay": True,
    },
}


def png_size(path: Path) -> tuple[int, int]:
    if not path.is_file():
        raise ValueError(f"missing OpenRTP atlas: {path}")
    with path.open("rb") as image_file:
        header = image_file.read(24)
    if len(header) != 24 or header[:8] != PNG_SIGNATURE or header[12:16] != b"IHDR":
        raise ValueError(f"not a valid PNG atlas: {path}")
    return struct.unpack(">II", header[16:24])


def png_chunk(chunk_type: bytes, chunk_data: bytes) -> bytes:
    checksum = zlib.crc32(chunk_type)
    checksum = zlib.crc32(chunk_data, checksum) & 0xFFFFFFFF
    return struct.pack(">I", len(chunk_data)) + chunk_type + chunk_data + struct.pack(">I", checksum)


def parse_png_chunks(source: bytes) -> list[tuple[bytes, bytes]]:
    if not source.startswith(PNG_SIGNATURE):
        raise ValueError("OpenRTP exterior source is not a PNG")
    chunks: list[tuple[bytes, bytes]] = []
    offset = len(PNG_SIGNATURE)
    while offset < len(source):
        if offset + 12 > len(source):
            raise ValueError("truncated OpenRTP exterior PNG chunk")
        length = struct.unpack(">I", source[offset : offset + 4])[0]
        chunk_type = source[offset + 4 : offset + 8]
        data_start = offset + 8
        data_end = data_start + length
        chunk_end = data_end + 4
        if chunk_end > len(source):
            raise ValueError("truncated OpenRTP exterior PNG data")
        chunk_data = source[data_start:data_end]
        expected_crc = struct.unpack(">I", source[data_end:chunk_end])[0]
        actual_crc = zlib.crc32(chunk_type)
        actual_crc = zlib.crc32(chunk_data, actual_crc) & 0xFFFFFFFF
        if actual_crc != expected_crc:
            raise ValueError(f"invalid CRC in OpenRTP exterior PNG chunk {chunk_type!r}")
        chunks.append((chunk_type, chunk_data))
        offset = chunk_end
        if chunk_type == b"IEND":
            if offset != len(source):
                raise ValueError("unexpected data after OpenRTP exterior PNG IEND")
            return chunks
    raise ValueError("OpenRTP exterior PNG has no IEND chunk")


def transparent_exterior(source: bytes) -> tuple[bytes, list[int]]:
    chunks = parse_png_chunks(source)
    header = next((data for chunk_type, data in chunks if chunk_type == b"IHDR"), None)
    palette = next((data for chunk_type, data in chunks if chunk_type == b"PLTE"), None)
    if header is None or len(header) != 13 or header[9] != 3:
        raise ValueError("OpenRTP exterior PNG must use indexed color")
    if palette is None or len(palette) % 3 != 0:
        raise ValueError("OpenRTP exterior PNG has no valid palette")

    chroma_indices = [
        index
        for index in range(len(palette) // 3)
        if tuple(palette[index * 3 : index * 3 + 3]) == CHROMA_RGB
    ]
    if not chroma_indices:
        raise ValueError("OpenRTP exterior PNG is missing the expected #FF678B chroma key")

    existing_transparency = next(
        (data for chunk_type, data in chunks if chunk_type == b"tRNS"), b""
    )
    alphas = bytearray([255] * (max(chroma_indices) + 1))
    alphas[: min(len(alphas), len(existing_transparency))] = existing_transparency[: len(alphas)]
    for palette_index in chroma_indices:
        alphas[palette_index] = 0

    output = bytearray(PNG_SIGNATURE)
    for chunk_type, chunk_data in chunks:
        if chunk_type == b"tRNS":
            continue
        output.extend(png_chunk(chunk_type, chunk_data))
        if chunk_type == b"PLTE":
            output.extend(png_chunk(b"tRNS", bytes(alphas)))
    return bytes(output), chroma_indices


def derivative_outputs(project_root: Path) -> dict[Path, bytes]:
    source_path = project_root / ATLAS_PATHS["exterior"]
    source = source_path.read_bytes()
    derived, chroma_indices = transparent_exterior(source)
    provenance = {
        "artifact": DERIVED_EXTERIOR_PATH.name,
        "derived_from": "../exterior.png",
        "derived_sha256": hashlib.sha256(derived).hexdigest(),
        "generator": "tools/build_openrtp_maps.py",
        "license": "CC0-1.0",
        "operation": "set OpenRTP #FF678B palette entries transparent",
        "source_pack": "openrtp",
        "source_sha256": hashlib.sha256(source).hexdigest(),
        "transparent_palette_indices": chroma_indices,
        "transparent_rgb": "#FF678B",
    }
    return {
        project_root / DERIVED_EXTERIOR_PATH: derived,
        project_root / DERIVED_PROVENANCE_PATH: (
            json.dumps(provenance, indent=2, sort_keys=True) + "\n"
        ).encode("utf-8"),
    }


def atlas_dimensions(project_root: Path) -> dict[str, tuple[int, int]]:
    dimensions: dict[str, tuple[int, int]] = {}
    for atlas_name, relative_path in ATLAS_PATHS.items():
        width, height = png_size(project_root / relative_path)
        if width % TILE_SIZE != 0 or height % TILE_SIZE != 0:
            raise ValueError(
                f"OpenRTP atlas must use a {TILE_SIZE}px grid: {relative_path} is {width}x{height}"
            )
        dimensions[atlas_name] = (width, height)

    for atlas_name, named_tiles in ATLAS_TILES.items():
        width, height = dimensions[atlas_name]
        for tile_name, (column, row) in named_tiles.items():
            source_x = column * TILE_SIZE
            source_y = row * TILE_SIZE
            if source_x + TILE_SIZE > width or source_y + TILE_SIZE > height:
                raise ValueError(
                    f"OpenRTP tile '{tile_name}' is outside {atlas_name}.png at ({source_x}, {source_y})"
                )
    return dimensions


def tile_entry(
    cell_x: int,
    cell_y: int,
    atlas_name: str,
    tile_name: str,
    dimensions: dict[str, tuple[int, int]],
) -> dict[str, Any]:
    column, row = ATLAS_TILES[atlas_name][tile_name]
    atlas_columns = dimensions[atlas_name][0] // TILE_SIZE
    tile_id = row * atlas_columns + column
    return {
        "px": [cell_x * TILE_SIZE, cell_y * TILE_SIZE],
        "srcId": tile_id,
        "t": tile_id,
        "f": 0,
    }


def ground_tiles(
    recipe_name: str,
    width: int,
    height: int,
    dimensions: dict[str, tuple[int, int]],
) -> list[dict[str, Any]]:
    tiles: list[dict[str, Any]] = []
    grass = ("grass_a", "grass_b", "grass_c", "grass_d")
    for cell_y in range(height):
        for cell_x in range(width):
            if recipe_name == "meadow_road":
                on_path = 6 <= cell_y <= 8
                path_top = cell_y == 6
                path_bottom = cell_y == 8
            elif recipe_name == "clearing_path":
                in_clearing = 5 <= cell_x <= 14 and 4 <= cell_y <= 10
                west_approach = cell_x < 5 and 6 <= cell_y <= 8
                east_approach = cell_x > 14 and 6 <= cell_y <= 8
                on_path = in_clearing or west_approach or east_approach
                path_top = (in_clearing and cell_y == 4) or (
                    (west_approach or east_approach) and cell_y == 6
                )
                path_bottom = (in_clearing and cell_y == 10) or (
                    (west_approach or east_approach) and cell_y == 8
                )
            elif recipe_name == "campsite_expanded":
                central_clearing = 11 <= cell_x <= 28 and 9 <= cell_y <= 18
                west_approach = cell_x <= 10 and 14 <= cell_y <= 15
                east_approach = cell_x >= 29 and 14 <= cell_y <= 15
                north_lesson_path = 18 <= cell_x <= 22 and 4 <= cell_y <= 8
                south_return_path = 18 <= cell_x <= 22 and 19 <= cell_y <= 25
                on_path = (
                    central_clearing
                    or west_approach
                    or east_approach
                    or north_lesson_path
                    or south_return_path
                )
                path_top = (
                    (11 <= cell_x <= 28 and cell_y == 9)
                    or (18 <= cell_x <= 22 and cell_y == 4)
                    or (18 <= cell_x <= 22 and cell_y == 19)
                    or ((west_approach or east_approach) and cell_y == 14)
                )
                path_bottom = (
                    (11 <= cell_x <= 28 and cell_y == 18)
                    or (18 <= cell_x <= 22 and cell_y == 8)
                    or (18 <= cell_x <= 22 and cell_y == 25)
                    or ((west_approach or east_approach) and cell_y == 15)
                )
            else:
                raise ValueError(f"unknown ground recipe: {recipe_name}")

            if on_path:
                if path_top:
                    tile_name = "dirt_top"
                elif path_bottom:
                    tile_name = "dirt_bottom"
                else:
                    tile_name = "dirt_center"
            else:
                tile_name = grass[(cell_x * 3 + cell_y * 5) % len(grass)]
            tiles.append(tile_entry(cell_x, cell_y, "world", tile_name, dimensions))
    return tiles


def add_prop(
    output: list[dict[str, Any]],
    cell_x: int,
    cell_y: int,
    tile_name: str,
    dimensions: dict[str, tuple[int, int]],
) -> None:
    output.append(tile_entry(cell_x, cell_y, "exterior", tile_name, dimensions))


def add_small_tree(
    output: list[dict[str, Any]],
    cell_x: int,
    cell_y: int,
    dimensions: dict[str, tuple[int, int]],
) -> None:
    add_prop(output, cell_x, cell_y, "tree_top", dimensions)
    add_prop(output, cell_x, cell_y + 1, "tree_bottom", dimensions)


def add_large_tree(
    output: list[dict[str, Any]],
    cell_x: int,
    cell_y: int,
    dimensions: dict[str, tuple[int, int]],
) -> None:
    for offset_x, offset_y, tile_name in (
        (0, 0, "large_tree_top_left"),
        (1, 0, "large_tree_top_right"),
        (0, 1, "large_tree_bottom_left"),
        (1, 1, "large_tree_bottom_right"),
    ):
        add_prop(output, cell_x + offset_x, cell_y + offset_y, tile_name, dimensions)


def add_tent(
    output: list[dict[str, Any]],
    cell_x: int,
    cell_y: int,
    dimensions: dict[str, tuple[int, int]],
) -> None:
    for offset_x, offset_y, tile_name in (
        (0, 0, "tent_top_left"),
        (1, 0, "tent_top_right"),
        (0, 1, "tent_bottom_left"),
        (1, 1, "tent_bottom_right"),
    ):
        add_prop(output, cell_x + offset_x, cell_y + offset_y, tile_name, dimensions)


def prop_tiles(
    map_name: str,
    recipe_names: list[str],
    width: int,
    height: int,
    dimensions: dict[str, tuple[int, int]],
) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    for recipe_name in recipe_names:
        if recipe_name == "tree_border":
            for cell_x in range(1, width - 1, 3):
                add_small_tree(output, cell_x, 0, dimensions)
                add_small_tree(output, cell_x, height - 2, dimensions)
            for cell_y in range(3, height - 3, 4):
                add_small_tree(output, 0, cell_y, dimensions)
                add_small_tree(output, width - 1, cell_y, dimensions)
        elif recipe_name == "dense_tree_border":
            for cell_x in range(0, width - 1, 3):
                add_large_tree(output, cell_x, 0, dimensions)
                add_large_tree(output, cell_x, height - 2, dimensions)
            for cell_y in range(3, height - 3, 3):
                add_large_tree(output, 0, cell_y, dimensions)
                add_large_tree(output, width - 2, cell_y, dimensions)
        elif recipe_name == "wildflowers":
            for cell_x, cell_y in ((3, 3), (6, 10), (13, 2), (16, 11)):
                add_prop(output, cell_x, cell_y, "wildflowers", dimensions)
        elif recipe_name == "fence":
            for start_x, cell_y in ((2, 4), (15, 10)):
                add_prop(output, start_x, cell_y, "fence_left", dimensions)
                add_prop(output, start_x + 1, cell_y, "fence_middle", dimensions)
                add_prop(output, start_x + 2, cell_y, "fence_right", dimensions)
        elif recipe_name == "fire_ring":
            add_prop(output, 20, 13, "campfire", dimensions)
        elif recipe_name == "bedroll":
            add_prop(output, 17, 14, "bedroll", dimensions)
        elif recipe_name == "camp_tent":
            tent_positions = [(10, 3)] if map_name == "caravan_route" else [(12, 11), (25, 11)]
            for tent_position in tent_positions:
                add_tent(output, *tent_position, dimensions)
        elif recipe_name == "crate":
            crate_positions = [(13, 4)] if map_name == "caravan_route" else [(27, 13), (15, 16)]
            for crate_position in crate_positions:
                add_prop(output, *crate_position, "crate", dimensions)
        elif recipe_name == "lesson_grove":
            for tree_position in [(13, 2), (17, 2), (23, 2), (27, 2), (14, 4), (26, 4)]:
                add_large_tree(output, *tree_position, dimensions)
            for flower_position in [(16, 6), (24, 6), (15, 8), (26, 8)]:
                add_prop(output, *flower_position, "wildflowers", dimensions)
        elif recipe_name == "south_trail":
            for rock_position in [(7, 20), (31, 20), (10, 24), (29, 24)]:
                add_prop(output, *rock_position, "rock", dimensions)
            for start_x, cell_y in ((13, 22), (25, 22)):
                add_prop(output, start_x, cell_y, "fence_left", dimensions)
                add_prop(output, start_x + 1, cell_y, "fence_middle", dimensions)
                add_prop(output, start_x + 2, cell_y, "fence_right", dimensions)
        else:
            raise ValueError(f"unknown props recipe: {recipe_name}")
    return output


def expanded_collision_csv(map_name: str, width: int, height: int) -> str:
    """Build the walkable shell and readable lesson/creek barriers."""
    rows = [[0 for _ in range(width)] for _ in range(height)]
    for cell_x in range(width):
        rows[0][cell_x] = 1
        rows[height - 1][cell_x] = 1
    for cell_y in range(height):
        rows[cell_y][0] = 1
        rows[cell_y][width - 1] = 1

    if map_name == "forest_campsite":
        for cell_x in range(12, 29):
            if cell_x not in (16, 24):
                rows[6][cell_x] = 1
        for cell_x in range(8, 33):
            if cell_x not in (17, 24):
                rows[22][cell_x] = 1
        for cell_y in (14, 15):
            rows[cell_y][0] = 0
            rows[cell_y][width - 1] = 0
    return "\n".join(",".join(str(value) for value in row) for row in rows)


def tileset_definition(
    uid: int,
    identifier: str,
    relative_path: str,
    dimensions: tuple[int, int],
) -> dict[str, Any]:
    return {
        "uid": uid,
        "identifier": identifier,
        "relPath": relative_path,
        "pxWid": dimensions[0],
        "pxHei": dimensions[1],
        "tileGridSize": TILE_SIZE,
        "spacing": 0,
        "padding": 0,
        "tags": [],
        "tagsSourceEnumUid": None,
        "enumTags": [],
        "customData": [],
    }


def gameplay_payload(project: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        {
            "identifier": level.get("identifier", ""),
            "layerInstances": [
                deepcopy(layer)
                for layer in level.get("layerInstances", [])
                if layer.get("__type") in ("IntGrid", "Entities")
            ],
        }
        for level in project.get("levels", [])
    ]


def layer_by_name(layers: list[dict[str, Any]], layer_name: str, context: str) -> dict[str, Any]:
    matches = [layer for layer in layers if layer.get("identifier") == layer_name]
    if len(matches) != 1:
        raise ValueError(f"expected one '{layer_name}' layer in {context}, found {len(matches)}")
    return matches[0]


def rebuild_project(
    project: dict[str, Any],
    map_name: str,
    dimensions: dict[str, tuple[int, int]],
) -> dict[str, Any]:
    baseline = gameplay_payload(project)
    recipe = RECIPES[map_name]

    definitions = project.get("defs")
    if not isinstance(definitions, dict):
        raise ValueError(f"missing LDtk definitions in {map_name}")
    layer_definitions = definitions.get("layerDefs")
    if not isinstance(layer_definitions, list):
        raise ValueError(f"missing LDtk layer definitions in {map_name}")
    ground_definition = layer_by_name(layer_definitions, "Ground", f"{map_name} definitions")
    props_definition = layer_by_name(layer_definitions, "Props", f"{map_name} definitions")
    ground_definition["tilesetDefUid"] = WORLD_TILESET_UID
    props_definition["tilesetDefUid"] = EXTERIOR_TILESET_UID

    definitions["tilesets"] = [
        tileset_definition(
            WORLD_TILESET_UID,
            "openrtp_world",
            "../art/tilesets/openrtp/world.png",
            dimensions["world"],
        ),
        tileset_definition(
            EXTERIOR_TILESET_UID,
            "openrtp_exterior",
            PROPS_TILESET_REL_PATH,
            dimensions["exterior"],
        ),
    ]

    levels = project.get("levels")
    if not isinstance(levels, list) or not levels:
        raise ValueError(f"missing LDtk level in {map_name}")
    for level in levels:
        layer_instances = level.get("layerInstances")
        if not isinstance(layer_instances, list):
            raise ValueError(f"missing layer instances in {map_name}")
        ground_layer = layer_by_name(layer_instances, "Ground", f"{map_name} level")
        props_layer = layer_by_name(layer_instances, "Props", f"{map_name} level")
        grid_size = ground_layer.get("__gridSize")
        if grid_size != TILE_SIZE or props_layer.get("__gridSize") != TILE_SIZE:
            raise ValueError(f"{map_name} Ground and Props layers must use a {TILE_SIZE}px grid")
        width, height = recipe["size"]
        if not isinstance(width, int) or not isinstance(height, int):
            raise ValueError(f"invalid recipe dimensions in {map_name}")

        level["pxWid"] = width * TILE_SIZE
        level["pxHei"] = height * TILE_SIZE
        for layer in layer_instances:
            layer["__cWid"] = width
            layer["__cHei"] = height

        ground_layer["gridTiles"] = ground_tiles(recipe["ground"], width, height, dimensions)
        ground_layer["__tilesetRelPath"] = "../art/tilesets/openrtp/world.png"
        props_layer["gridTiles"] = prop_tiles(map_name, recipe["props"], width, height, dimensions)
        props_layer["__tilesetRelPath"] = PROPS_TILESET_REL_PATH

        if recipe["expand_gameplay"]:
            collision_layer = layer_by_name(layer_instances, "Collision", f"{map_name} level")
            collision_layer["intGridCsv"] = expanded_collision_csv(map_name, width, height)
            zero_grid = "\n".join(
                ",".join("0" for _ in range(width)) for _ in range(height)
            )
            for layer_name in ("Decoration", "Foreground", "Lighting"):
                layer_by_name(layer_instances, layer_name, f"{map_name} level")["intGridCsv"] = zero_grid

        if map_name == "forest_campsite":
            entities_layer = layer_by_name(layer_instances, "Entities", f"{map_name} level")
            entity_positions = {
                "Spawn": [112, 240],
                "Door": [32, 240],
                "Interaction": [320, 176],
            }
            for entity in entities_layer.get("entityInstances", []):
                identifier = entity.get("__identifier")
                if identifier in entity_positions:
                    entity["px"] = entity_positions[identifier]

    if not recipe["expand_gameplay"] and gameplay_payload(project) != baseline:
        raise RuntimeError(f"refusing to write {map_name}: gameplay layers changed")
    return project


def atomic_replace_outputs(outputs: dict[Path, bytes]) -> None:
    temporary_paths: dict[Path, Path] = {}
    try:
        for output_path, content in outputs.items():
            output_path.parent.mkdir(parents=True, exist_ok=True)
            file_descriptor, temporary_name = tempfile.mkstemp(
                prefix=f".{output_path.name}.",
                dir=output_path.parent,
            )
            temporary_path = Path(temporary_name)
            temporary_paths[output_path] = temporary_path
            with os.fdopen(file_descriptor, "wb") as output_file:
                output_file.write(content)
                output_file.flush()
                os.fsync(output_file.fileno())
        for output_path, temporary_path in temporary_paths.items():
            os.replace(temporary_path, output_path)
    finally:
        for temporary_path in temporary_paths.values():
            temporary_path.unlink(missing_ok=True)


def build_maps(project_root: Path) -> int:
    try:
        dimensions = atlas_dimensions(project_root)
        outputs = derivative_outputs(project_root)
        build_records: list[tuple[str, int, int]] = []

        # Validate and serialize every project before creating any output file.
        for map_name in RECIPES:
            map_path = project_root / "maps" / f"{map_name}.ldtk"
            project = json.loads(map_path.read_text(encoding="utf-8"))
            rebuilt = rebuild_project(project, map_name, dimensions)
            outputs[map_path] = (json.dumps(rebuilt, indent=2) + "\n").encode("utf-8")
            layers = rebuilt["levels"][0]["layerInstances"]
            ground_count = len(layer_by_name(layers, "Ground", map_name)["gridTiles"])
            props_count = len(layer_by_name(layers, "Props", map_name)["gridTiles"])
            build_records.append((map_path.name, ground_count, props_count))

        atomic_replace_outputs(outputs)
        for map_filename, ground_count, props_count in build_records:
            print(f"BUILT: {map_filename} ({ground_count} ground, {props_count} props)")
        print(f"BUILT: {DERIVED_EXTERIOR_PATH}")
    except (OSError, KeyError, RuntimeError, TypeError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}")
        return 1
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="Godot project root (defaults to this script's repository).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    return build_maps(args.project_root.resolve())


if __name__ == "__main__":
    sys.exit(main())
