# Opening Art Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the opening slice's prototype tiles and procedural camp art with a provenance-tracked CC0 art package covering caravan, campsite, wilderness depth, and Tarbean narration.

**Architecture:** OpenRTP remains the only 16×16 playable-map atlas, preserving the LDtk grid and all collision/entity payloads. Frontier Wagons become composite source-backed props, Gloomy Fantasy becomes a non-interactive distant backdrop, and Kenney RPG Urban becomes a non-interactive Tarbean narration canvas. Deterministic import and generation tools own all source paths, hashes, and source-region mappings.

**Tech Stack:** Godot 4.7, LDtk JSON, GDScript SceneTree tests, Python 3 standard library image/JSON tooling, committed PNG assets.

**Spec:** `docs/superpowers/specs/2026-08-26-openrtp-opening-art-design.md`

## Global Constraints

- Use only the four documented CC0 packs: OpenRTP, Pixel Gloomy Fantasy,
  Frontier Wagons, and Kenney RPG Urban.
- Preserve all existing `IntGrid`, Spawn, Door, and Interaction JSON data.
- Keep the 16×16 playable-map grid and all scene paths, saves, dialogue, and
  gameplay rules unchanged.
- Presentation nodes are visual-only and may not add physics, input, state,
  or triggers.
- Track upstream art unmodified, record SHA-256 provenance, and generate all
  composites deterministically.
- Use nearest-neighbor texture filtering; never smooth pixel art.
- Refresh Godot imports after adding scripts/resources; each test prints a
  final `*_TEST: PASS` line and exits non-zero on failure.

---

### Task 1: Import source packs and provenance records

**Files:**
- Create: `tools/import_opening_art.py`
- Create: `art/tilesets/openrtp/{world,exterior,interior,dungeon,ship}.png`
- Create: `art/tilesets/openrtp/PROVENANCE.json`
- Create: `art/tilesets/gloomy_fantasy/*`
- Create: `art/props/frontier_wagons/frontier_wagons.png`
- Create: `art/props/frontier_wagons/PROVENANCE.json`
- Create: `art/tilesets/kenney_rpg_urban/*`
- Create: `art/tilesets/{gloomy_fantasy,kenney_rpg_urban}/PROVENANCE.json`
- Test: `tests/test_opening_art.gd`

**Interfaces:**
- Consumes: `/Users/spkoehl/Downloads/openRPG_Tilesets_5.24.22/` and official
  creator downloads staged under `/private/tmp/opening-art-sources/`.
- Produces: `import_opening_art.py --source-root <path>` which returns `0` only
  when every source image and CC0 provenance record has a verified SHA-256.

- [ ] **Step 1: Write the failing source/provenance test**

```gdscript
for record_path in [
	"res://art/tilesets/openrtp/PROVENANCE.json",
	"res://art/tilesets/gloomy_fantasy/PROVENANCE.json",
	"res://art/props/frontier_wagons/PROVENANCE.json",
	"res://art/tilesets/kenney_rpg_urban/PROVENANCE.json",
]:
	_check(FileAccess.file_exists(record_path), "provenance exists: " + record_path)
	var record := JSON.parse_string(FileAccess.get_file_as_string(record_path)) as Dictionary
	_check(record.get("license") == "CC0-1.0", "source is CC0: " + record_path)
	_check(record.has("sha256") and record.has("source_url"), "source is auditable: " + record_path)
```

- [ ] **Step 2: Run the focused suite and verify red**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_opening_art.gd`

Expected: `OPENING_ART_TEST: FAIL` because provenance records do not exist.

- [ ] **Step 3: Implement deterministic asset import**

Implement `tools/import_opening_art.py` with a fixed `SOURCES` dictionary:

```python
SOURCES = {
    "openrtp": ["world.png", "exterior.png", "interior.png", "dungeon.png", "ship.png", "ReadMe.txt"],
    "gloomy_fantasy": ["Pixel Fantasy Tileset.png"],
    "frontier_wagons": ["frontier_wagons.png"],
    "kenney_rpg_urban": ["Tilemap/tilemap_packed.png", "License.txt"],
}
```

For every file, copy bytes only when the source is present, compute SHA-256,
write a `PROVENANCE.json` with `pack_id`, `creator`, `source_url`,
`license`, `downloaded_at`, `files`, and `sha256`, and return a non-zero exit
after printing every missing path. Include source `ReadMe.txt`/`License.txt`
beside the imported art.

- [ ] **Step 4: Import the assets and verify green**

Run the tool against `/private/tmp/opening-art-sources/`, refresh Godot, then:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_opening_art.gd
```

Expected: `OPENING_ART_TEST: PASS`.

- [ ] **Step 5: Commit**

```sh
git add tools/import_opening_art.py art/tilesets art/props tests/test_opening_art.gd
git commit -m "feat: import licensed opening art"
```

### Task 2: Re-author OpenRTP map layers without gameplay changes

**Files:**
- Create: `tools/build_openrtp_maps.py`
- Modify: `maps/caravan_route.ldtk`
- Modify: `maps/forest_campsite.ldtk`
- Modify: `tests/test_opening_art.gd`

**Interfaces:**
- Consumes: OpenRTP `world.png` and `exterior.png`, plus current LDtk project
  data.
- Produces: `build_openrtp_maps.py` which rewrites only each level's `Ground`
  and `Props` layer tile arrays and tileset paths.

- [ ] **Step 1: Write the failing visual-map contract**

```gdscript
for map_path in ["res://maps/caravan_route.ldtk", "res://maps/forest_campsite.ldtk"]:
	var source := FileAccess.get_file_as_string(map_path)
	_check(not source.contains("zeldalike_overworld.png"), "legacy atlas removed: " + map_path)
	_check(source.contains("openrtp/world.png"), "OpenRTP world atlas mapped: " + map_path)
	_check(source.contains("openrtp/exterior.png"), "OpenRTP exterior atlas mapped: " + map_path)
```

- [ ] **Step 2: Capture baseline gameplay payloads and verify red**

Before rewrites, store normalized `{layerInstances: IntGrid + Entities}`
snapshots in `tests/fixtures/opening_art_baseline.json`; run the focused suite
and expect map-atlas checks to fail.

- [ ] **Step 3: Implement map builder**

Implement exact named tile recipes such as:

```python
RECIPES = {
    "caravan_route": {"ground": "meadow_road", "props": ["tree_border", "wildflowers", "fence", "camp_tent", "crate"]},
    "forest_campsite": {"ground": "clearing_path", "props": ["dense_tree_border", "fire_ring", "bedroll", "camp_tent", "crate"]},
}
```

Resolve each recipe to explicit OpenRTP atlas pixel coordinates, calculate
`t`, `px`, and `py` for LDtk tile entries, change only `Ground`/`Props`, and
copy the original `IntGrid` and entity arrays unchanged. Reject a non-16px
atlas or a missing layer name.

- [ ] **Step 4: Build maps and verify gameplay preservation**

Run the map builder, then run:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_opening_art.gd
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_world_traversal.gd
```

Expected: `OPENING_ART_TEST: PASS` and `WORLD_TRAVERSAL_TEST: PASS`.

- [ ] **Step 5: Commit**

```sh
git add tools/build_openrtp_maps.py maps tests/fixtures/opening_art_baseline.json tests/test_opening_art.gd
git commit -m "feat: reauthor opening maps with OpenRTP"
```

### Task 3: Replace procedural caravan art with licensed source-backed props

**Files:**
- Create: `tools/build_opening_art.py`
- Create: `art/generated/opening_art/{caravan_wagon_a,caravan_wagon_b,campfire,tent_shadow}.png`
- Modify: `scripts/world/caravan_presentation.gd`
- Modify: `scenes/world/caravan_presentation.tscn`
- Modify: `tests/test_opening_art.gd`

**Interfaces:**
- Consumes: `frontier_wagons.png` and OpenRTP source atlas regions.
- Produces: `OpeningArtPresentation.set_reduced_motion(enabled: bool)` and
  generated source-backed PNG textures loaded by `CaravanPresentation`.

- [ ] **Step 1: Write the failing presentation test**

```gdscript
var caravan_source := FileAccess.get_file_as_string("res://scripts/world/caravan_presentation.gd")
_check(not caravan_source.contains("draw_colored_polygon"), "caravan no longer draws primitive tents or fire")
_check(not caravan_source.contains("draw_circle"), "caravan no longer draws primitive trees or wheels")
_check(caravan_source.contains("res://art/generated/opening_art/caravan_wagon_a.png"), "caravan loads generated wagon art")
```

- [ ] **Step 2: Run focused suite and verify red**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_opening_art.gd`

Expected: `OPENING_ART_TEST: FAIL` on procedural-art assertions.

- [ ] **Step 3: Implement compositing and sprite-based presentation**

Generate wagon sprites by extracting the selected Frontier Wagon regions,
placing OpenRTP crates/canvas accents on transparent canvases, and saving
nearest-neighbor PNGs. Replace `_draw_wagons`, `_draw_tents`, `_draw_campfire`,
and `_draw_canopy` with positioned `Sprite2D` nodes in the scene. Retain only
shadow/tint and fire ember motion in code; suppress motion under
`Settings.reduce_motion`.

- [ ] **Step 4: Verify the visual-only contract**

Run the opening and combat suites:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_opening_art.gd
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_combat_puzzles.gd
```

Expected: both final lines report `PASS`.

- [ ] **Step 5: Commit**

```sh
git add tools/build_opening_art.py art/generated/opening_art scripts/world/caravan_presentation.gd scenes/world/caravan_presentation.tscn tests/test_opening_art.gd
git commit -m "feat: replace caravan placeholder art"
```

### Task 4: Add Gloomy wilderness depth and Kenney Tarbean vignette

**Files:**
- Create: `scripts/world/wilderness_backdrop.gd`
- Create: `scenes/world/wilderness_backdrop.tscn`
- Create: `scripts/world/tarbean_road_canvas.gd`
- Modify: `scenes/world/caravan_route.tscn`
- Modify: `scenes/world/forest_campsite.tscn`
- Modify: `scenes/world/tarbean_road.tscn`
- Modify: `tests/test_opening_art.gd`

**Interfaces:**
- Consumes: Gloomy Fantasy source art and Kenney RPG Urban tilemap.
- Produces: `WildernessBackdrop` and `TarbeanRoadCanvas` visual nodes that
  expose `render_signature() -> Dictionary` for tests.

- [ ] **Step 1: Write the failing scene-art tests**

```gdscript
_check(ResourceLoader.exists("res://scenes/world/wilderness_backdrop.tscn"), "wilderness backdrop exists")
var tarbean := load("res://scenes/world/tarbean_road.tscn") as PackedScene
var tarbean_scene := tarbean.instantiate()
_check(tarbean_scene.get_node_or_null("TarbeanRoadCanvas") != null, "Tarbean has an urban art canvas")
```

- [ ] **Step 2: Run focused suite and verify red**

Expected: `OPENING_ART_TEST: FAIL` because neither visual node exists.

- [ ] **Step 3: Implement visual-only nodes**

`WildernessBackdrop` uses a nearest-neighbor Gloomy Fantasy texture in a
`CanvasLayer` behind world content, with `parallax_factor = Vector2(0.18, 0.12)`
and no collision children. `TarbeanRoadCanvas` builds a dark city-edge collage
from Kenney sprites behind `OverlayLayer`, uses reduced-motion-safe rain tint,
and never changes BeatCutscene data.

- [ ] **Step 4: Verify scene behavior and routing**

Run:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_opening_art.gd
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_combat_puzzles.gd
```

Expected: both suites pass; Tarbean narration still reaches the existing end
card route.

- [ ] **Step 5: Commit**

```sh
git add scripts/world/wilderness_backdrop.gd scenes/world/wilderness_backdrop.tscn scripts/world/tarbean_road_canvas.gd scenes/world/caravan_route.tscn scenes/world/forest_campsite.tscn scenes/world/tarbean_road.tscn tests/test_opening_art.gd
git commit -m "feat: add licensed opening atmosphere"
```

### Task 5: Capture, document, and regress the finished opening

**Files:**
- Modify: `tools/capture_opening_screenshots.gd`
- Create: `docs/screenshots/forest-campsite-openrtp.png`
- Create: `docs/screenshots/tarbean-urban.png`
- Modify: `docs/screenshots/caravan-dawn.png`
- Modify: `README.md`
- Modify: `tests/test_opening_presentation.gd`
- Modify: `tests/test_opening_art.gd`

**Interfaces:**
- Consumes: final caravan, campsite, and Tarbean scenes.
- Produces: six declared capture mappings and 1280×720 committed PNGs.

- [ ] **Step 1: Write the failing capture contract**

```gdscript
for filename in ["caravan-dawn.png", "forest-campsite-openrtp.png", "tarbean-urban.png"]:
	_check(capture_source.contains(filename), "capture declares final art screenshot: " + filename)
	_check(FileAccess.file_exists("res://docs/screenshots/" + filename), "final art screenshot exists: " + filename)
```

- [ ] **Step 2: Run the opening suites and verify red**

Expected: `OPENING_PRESENTATION_TEST: FAIL` or `OPENING_ART_TEST: FAIL` until
the new mappings and PNGs exist.

- [ ] **Step 3: Extend graphical capture and README**

Add exact scene/file mappings for `forest_campsite.tscn` and
`tarbean_road.tscn`, apply deterministic camera framing, and preserve the
existing title no-save and reduce-motion state restoration. Embed the finished
three world captures in README beside their source-pack credits.

- [ ] **Step 4: Verify assets and gameplay**

Run graphical capture, check all PNGs with `sips -g pixelWidth -g pixelHeight`,
then run:

```sh
node tools/validate_content.mjs
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_opening_presentation.gd
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_opening_art.gd
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_world_traversal.gd
```

Expected: every applicable command has its stated PASS result.

- [ ] **Step 5: Commit and push**

```sh
git add README.md tools/capture_opening_screenshots.gd docs/screenshots tests/test_opening_presentation.gd tests/test_opening_art.gd
git commit -m "docs: publish upgraded opening art"
git push origin codex/opening-presentation
```
