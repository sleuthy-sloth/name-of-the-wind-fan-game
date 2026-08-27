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


if __name__ == "__main__":
    unittest.main()
