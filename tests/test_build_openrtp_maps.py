#!/usr/bin/env python3
"""Failure-path tests for the deterministic OpenRTP LDtk builder."""

from __future__ import annotations

import contextlib
import io
import json
import shutil
import tempfile
import unittest
from pathlib import Path

import sys

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "tools"))

import build_openrtp_maps  # noqa: E402


class AtomicMapWriteTest(unittest.TestCase):
    def test_second_map_validation_failure_leaves_both_maps_unchanged(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            test_root = Path(temporary_directory)
            (test_root / "maps").mkdir(parents=True)
            (test_root / "art/tilesets/openrtp").mkdir(parents=True)
            for map_name in build_openrtp_maps.RECIPES:
                shutil.copy2(
                    PROJECT_ROOT / "maps" / f"{map_name}.ldtk",
                    test_root / "maps" / f"{map_name}.ldtk",
                )
            for atlas_name in ("world.png", "exterior.png"):
                shutil.copy2(
                    PROJECT_ROOT / "art/tilesets/openrtp" / atlas_name,
                    test_root / "art/tilesets/openrtp" / atlas_name,
                )

            caravan_path = test_root / "maps/caravan_route.ldtk"
            caravan = json.loads(caravan_path.read_text(encoding="utf-8"))
            for layer in caravan["levels"][0]["layerInstances"]:
                if layer.get("identifier") == "Ground":
                    layer["gridTiles"] = []
            caravan_path.write_text(json.dumps(caravan, indent=2) + "\n", encoding="utf-8")

            forest_path = test_root / "maps/forest_campsite.ldtk"
            forest = json.loads(forest_path.read_text(encoding="utf-8"))
            forest["levels"][0]["layerInstances"] = [
                layer
                for layer in forest["levels"][0]["layerInstances"]
                if layer.get("identifier") != "Props"
            ]
            forest_path.write_text(json.dumps(forest, indent=2) + "\n", encoding="utf-8")
            before = {
                map_name: (test_root / "maps" / f"{map_name}.ldtk").read_bytes()
                for map_name in build_openrtp_maps.RECIPES
            }

            build_output = io.StringIO()
            with contextlib.redirect_stdout(build_output):
                self.assertEqual(build_openrtp_maps.build_maps(test_root), 1)
            self.assertIn("expected one 'Props' layer", build_output.getvalue())
            self.assertFalse(
                (test_root / "art/tilesets/openrtp/derived/exterior_transparent.png").exists(),
                "derived output was written despite map validation failure",
            )
            for map_name, expected_bytes in before.items():
                self.assertEqual(
                    (test_root / "maps" / f"{map_name}.ldtk").read_bytes(),
                    expected_bytes,
                    f"{map_name} changed despite a later validation failure",
                )


class TutorialLayoutContractTest(unittest.TestCase):
    def test_forest_campsite_is_a_large_four_zone_tutorial_map(self) -> None:
        project = json.loads(
            (PROJECT_ROOT / "maps/forest_campsite.ldtk").read_text(encoding="utf-8")
        )
        level = project["levels"][0]
        self.assertEqual((level["pxWid"], level["pxHei"]), (640, 448))

        layers = {layer["identifier"]: layer for layer in level["layerInstances"]}
        for layer_name in ("Ground", "Props", "Collision", "Decoration", "Foreground", "Lighting", "Entities"):
            self.assertEqual(
                (layers[layer_name]["__cWid"], layers[layer_name]["__cHei"]),
                (40, 28),
                f"{layer_name} uses the expanded tutorial bounds",
            )

        entities = {
            entity["__identifier"]: tuple(entity["px"])
            for entity in layers["Entities"]["entityInstances"]
        }
        self.assertEqual(entities["Spawn"], (112, 240))
        self.assertEqual(entities["Door"], (32, 240))
        self.assertEqual(entities["Interaction"], (320, 176))

        collision_rows = [
            [int(cell) for cell in row.split(",")]
            for row in layers["Collision"]["intGridCsv"].splitlines()
        ]
        self.assertEqual(collision_rows[14][0], 0, "west arrival opening remains walkable")
        self.assertEqual(collision_rows[14][39], 0, "east tutorial opening remains walkable")
        self.assertEqual(collision_rows[6][20], 1, "north grove barrier is readable")
        self.assertEqual(collision_rows[22][20], 1, "south creek barrier is readable")


if __name__ == "__main__":
    unittest.main()
