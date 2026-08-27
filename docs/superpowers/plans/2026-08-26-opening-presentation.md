# Opening Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Chronicle-page title, illustrated Waystone prologue, dressed caravan opening, and committed runtime screenshots.

**Architecture:** `ChronicleCanvas` renders original deterministic in-engine art for the title and prologue. `CaravanPresentation` layers original scenery over the existing LDtk map without affecting gameplay. A shared prompt utility and capture tool make visual quality testable and reproducible.

**Tech Stack:** Godot 4.7, GDScript, existing SceneTree suites, LDtk, Markdown, Git/GitHub.

**Spec:** `docs/superpowers/specs/2026-08-26-opening-presentation-design.md`

## Global Constraints

- Preserve and never stage the existing uncommitted `project.godot` change.
- Implement in an isolated `codex/opening-presentation` worktree based on committed `main`.
- Use only original, in-engine visual rendering; add no copied or unverified assets.
- Do not change save schema, economy, threat rules, dialogue outcomes, or LDtk collision data.
- Retain Waystone skip/autosave behavior while changing only its final destination.
- Run `--import` after adding a `class_name` script, then run tests.
- Write every behavioral test first, observe its expected failure, then implement the smallest code that makes it pass.
- Commit PNG captures in `docs/screenshots/`, and push each commit to `origin`.

---

## File Structure

| Path | Responsibility |
| --- | --- |
| `scripts/ui/chronicle_canvas.gd` | Original parchment/ink/firelight renderer for title and prologue. |
| `scripts/ui/interaction_prompt.gd` | Binding-aware prompt label configuration. |
| `scripts/world/caravan_presentation.gd` | Original camp set dressing and optional low-motion ambience. |
| `scenes/world/caravan_presentation.tscn` | Presentation-scene wrapper for the caravan. |
| `scripts/world/world_scene.gd` | Optional presentation-scene instancing point. |
| `tests/test_opening_presentation.gd` | Opening, accessibility, routing, and screenshot-contract regression suite. |
| `tools/capture_opening_screenshots.gd` | Real-scene 1280×720 PNG capture utility. |
| `docs/screenshots/*.png` | GitHub-rendered opening screenshots. |

## Task 1: Establish the test-first opening suite

**Files:**
- Create: `tests/test_opening_presentation.gd`

**Interfaces:**
- Produces: final `OPENING_PRESENTATION_TEST: PASS` line and exit 0 only when every assertion succeeds.

- [ ] **Step 1: Write the failing suite**

```gdscript
extends SceneTree
var _failures := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)

func _run() -> void:
	_check(ResourceLoader.exists("res://scripts/ui/chronicle_canvas.gd"), "ChronicleCanvas exists")
	_check(ResourceLoader.exists("res://scripts/world/caravan_presentation.gd"), "CaravanPresentation exists")
	_check(FileAccess.file_exists("res://tools/capture_opening_screenshots.gd"), "capture tool exists")
	print("OPENING_PRESENTATION_TEST: %s" % ("PASS" if _failures == 0 else "FAIL (%d failure(s))" % _failures))
	quit(0 if _failures == 0 else 1)
```

- [ ] **Step 2: Verify red**

Run:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script tests/test_opening_presentation.gd
```

Expected: final line is `OPENING_PRESENTATION_TEST: FAIL` because all three files are absent.

- [ ] **Step 3: Keep this suite as the contract harness**

Before implementing each later task, add its test function to `_run()` and observe its expected failure.

## Task 2: Add the Chronicle canvas and title treatment

**Files:**
- Create: `scripts/ui/chronicle_canvas.gd`
- Modify: `scenes/ui/title_menu.tscn`
- Modify: `scripts/ui/title_menu.gd`
- Modify: `tests/test_opening_presentation.gd`

**Interfaces:**
- Produces: `ChronicleCanvas.set_illustration(value: Illustration) -> void` and `ChronicleCanvas.render_signature() -> Dictionary`.

- [ ] **Step 1: Add a failing title test**

```gdscript
func _test_title_canvas() -> void:
	var packed := load("res://scenes/ui/title_menu.tscn") as PackedScene
	_check(packed != null, "title scene loads")
	if packed == null:
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	var canvas := scene.get_node_or_null("ChronicleCanvas")
	_check(canvas != null, "title contains ChronicleCanvas")
	if canvas != null:
		var signature: Dictionary = canvas.render_signature()
		_check(signature.get("illustration") == "title_page", "title illustration is a chronicle page")
		_check(int(signature.get("layer_count", 0)) >= 6, "title has six visual layers")
	scene.queue_free()
```

- [ ] **Step 2: Verify red**

Run the opening suite. Expected: title canvas assertions fail because the script and scene child do not exist.

- [ ] **Step 3: Implement the smallest renderer**

Create `class_name ChronicleCanvas extends Control` with `TITLE_PAGE`, `WAYSTONE_FIRE`, and `CARAVAN_DAWN` illustration enum values. `_draw()` must use Godot draw primitives to render exactly these visual layers: parchment, page edge, ink border, scene silhouette, warm light pool, and ink detail. `render_signature()` returns the illustration name, layer count, and animation state. Read `/root/Settings.reduce_motion` in `_ready()`; only call `queue_redraw()` from `_process(delta)` when animation is enabled.

- [ ] **Step 4: Integrate and verify green**

Add a full-rect `ChronicleCanvas` after `Backdrop` in `title_menu.tscn`, assign `TITLE_PAGE`, and keep fade/text/buttons above it. Run:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --import --quit
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script tests/test_opening_presentation.gd
```

- [ ] **Step 5: Commit and push**

```sh
git add scripts/ui/chronicle_canvas.gd scenes/ui/title_menu.tscn scripts/ui/title_menu.gd tests/test_opening_presentation.gd
git commit -m "feat: add chronicle title presentation"
git push origin codex/opening-presentation
```

## Task 3: Convert Waystone to an illustrated prologue

**Files:**
- Modify: `scenes/world/waystone_inn.tscn`
- Modify: `data/story/waystone_opening.json`
- Modify: `tests/test_opening_presentation.gd`

**Interfaces:**
- Consumes: `ChronicleCanvas.Illustration.WAYSTONE_FIRE` and existing `BeatCutscene` data.
- Produces: final destination `res://scenes/world/caravan_route.tscn`.

- [ ] **Step 1: Add a failing prologue test**

```gdscript
func _test_waystone_prologue() -> void:
	var packed := load("res://scenes/world/waystone_inn.tscn") as PackedScene
	_check(packed != null, "Waystone prologue loads")
	if packed != null:
		var scene := packed.instantiate()
		root.add_child(scene)
		await process_frame
		var canvas := scene.get_node_or_null("ChronicleCanvas")
		_check(canvas != null, "Waystone has ChronicleCanvas")
		if canvas != null:
			_check(canvas.render_signature().get("illustration") == "waystone_fire", "Waystone draws fireplace page")
		scene.queue_free()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/waystone_opening.json"))
	var beats: Array = data.get("beats", [])
	_check((beats.back() as Dictionary).get("next_scene") == "res://scenes/world/caravan_route.tscn", "Waystone routes to caravan")
```

- [ ] **Step 2: Verify red, implement, and verify green**

Observe the test fail. Add a full-rect ChronicleCanvas behind `OverlayLayer` in `waystone_inn.tscn`, set `WAYSTONE_FIRE`, and change only the final JSON `next_scene`. Keep narration, duration, flags, and autosave unmodified. Run:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script tests/test_opening_presentation.gd
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script tests/test_combat_puzzles.gd
```

- [ ] **Step 3: Commit and push**

```sh
git add scenes/world/waystone_inn.tscn data/story/waystone_opening.json tests/test_opening_presentation.gd
git commit -m "feat: present Waystone as chronicle prologue"
git push origin codex/opening-presentation
```

## Task 4: Add the caravan presentation layer

**Files:**
- Create: `scripts/world/caravan_presentation.gd`
- Create: `scenes/world/caravan_presentation.tscn`
- Modify: `scripts/world/world_scene.gd`
- Modify: `scenes/world/caravan_route.tscn`
- Modify: `tests/test_opening_presentation.gd`

**Interfaces:**
- Consumes: `WorldScene.presentation_scene: PackedScene`.
- Produces: `CaravanPresentation` with `Canopy`, `Wagons`, `Tents`, `Campfire`, `Shadows`, and `Atmosphere` layers.

- [ ] **Step 1: Add a failing caravan test**

```gdscript
func _test_caravan_presentation() -> void:
	var packed := load("res://scenes/world/caravan_route.tscn") as PackedScene
	_check(packed != null, "caravan scene loads")
	if packed == null:
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var presentation := scene.get_node_or_null("CaravanPresentation")
	_check(presentation != null, "caravan instances presentation")
	for name in ["Canopy", "Wagons", "Tents", "Campfire", "Shadows", "Atmosphere"]:
		_check(presentation != null and presentation.get_node_or_null(name) != null, "caravan has " + name)
	scene.queue_free()
```

- [ ] **Step 2: Verify red, implement, and verify green**

Observe the new assertions fail. Add `@export var presentation_scene: PackedScene` to `WorldScene`; after `add_child(level)`, instance it when non-null before actor spawn. Implement `CaravanPresentation extends Node2D` with six named visual-only layers. Draw tree canopy, ground shadows, tent/wagon silhouettes, campfire, and bounded embers/leaves with original shapes; disable animation under reduce motion. Assign its scene to `caravan_route.tscn`.

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --import --quit
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script tests/test_opening_presentation.gd
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script tests/test_world_traversal.gd
```

- [ ] **Step 3: Commit and push**

```sh
git add scripts/world/caravan_presentation.gd scenes/world/caravan_presentation.tscn scripts/world/world_scene.gd scenes/world/caravan_route.tscn tests/test_opening_presentation.gd
git commit -m "feat: dress caravan opening"
git push origin codex/opening-presentation
```

## Task 5: Standardize binding-aware interaction feedback

**Files:**
- Create: `scripts/ui/interaction_prompt.gd`
- Modify: `scenes/npcs/npc.gd`
- Modify: `scripts/world/threat_trigger.gd`
- Modify: `scripts/world/sympathy_target.gd`
- Modify: `tests/test_opening_presentation.gd`

**Interfaces:**
- Produces: `InteractionPrompt.binding_label(action: StringName) -> String` and `InteractionPrompt.configure(label: Label, action: StringName, context: String, color: Color) -> void`.

- [ ] **Step 1: Add a failing prompt test**

```gdscript
func _test_interaction_prompt() -> void:
	_check(InteractionPrompt.binding_label(&"interact") == "E", "interact binding resolves to E")
	var label := Label.new()
	InteractionPrompt.configure(label, &"interact", "Speak with Abenthy", Color.WHITE)
	_check(label.text == "[E] Speak with Abenthy", "prompt combines binding and context")
```

- [ ] **Step 2: Verify red, implement, and verify green**

Observe the test fail because the class does not resolve. Implement the class as a `RefCounted`: prefer readable physical-key text for the first keyboard event, then event text, then `E`; configure text, font size 10, outline size 3, foreground, and near-black outline. Replace hardcoded prompt styling in NPC, threat, and Sympathy scripts; retain their existing signals/range logic.

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --import --quit
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script tests/test_opening_presentation.gd
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script tests/test_slice_polish.gd
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script tests/test_combat_puzzles.gd
```

- [ ] **Step 3: Commit and push**

```sh
git add scripts/ui/interaction_prompt.gd scenes/npcs/npc.gd scripts/world/threat_trigger.gd scripts/world/sympathy_target.gd tests/test_opening_presentation.gd
git commit -m "feat: unify world interaction feedback"
git push origin codex/opening-presentation
```

## Task 6: Capture and document runtime screenshots

**Files:**
- Create: `tools/capture_opening_screenshots.gd`
- Create: `docs/screenshots/title-chronicle.png`
- Create: `docs/screenshots/waystone-prologue.png`
- Create: `docs/screenshots/caravan-dawn.png`
- Modify: `README.md`
- Modify: `tests/test_opening_presentation.gd`

**Interfaces:**
- Produces: three exact 1280×720 PNG paths; exits non-zero if a scene, image, dimension, or write operation fails.

- [ ] **Step 1: Add failing capture-contract tests**

```gdscript
func _test_capture_contract() -> void:
	var source := FileAccess.get_file_as_string("res://tools/capture_opening_screenshots.gd")
	for filename in ["title-chronicle.png", "waystone-prologue.png", "caravan-dawn.png"]:
		_check(source.contains(filename), "capture declares " + filename)
```

- [ ] **Step 2: Verify red, implement, and generate screenshots**

Observe the test fail. Create `extends SceneTree` with this mapping:

```gdscript
const CAPTURES := [
	{"scene": "res://scenes/ui/title_menu.tscn", "file": "res://docs/screenshots/title-chronicle.png"},
	{"scene": "res://scenes/world/waystone_inn.tscn", "file": "res://docs/screenshots/waystone-prologue.png"},
	{"scene": "res://scenes/world/caravan_route.tscn", "file": "res://docs/screenshots/caravan-dawn.png"},
]
```

For each entry, call `change_scene_to_file`, await two process frames and `RenderingServer.frame_post_draw`, then capture `root.get_texture().get_image()`. Reject null or non-1280×720 images; save with `image.save_png(ProjectSettings.globalize_path(file))` and reject non-`OK`. Temporarily enable reduce motion and restore its prior value. Do not call SaveManager or use `user://`.

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --path . --script tools/capture_opening_screenshots.gd
```

- [ ] **Step 3: Inspect and commit**

Visually inspect all three real PNGs. Add a README Screenshots section with the three relative images and the capture command. Then:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script tests/test_opening_presentation.gd
git add tools/capture_opening_screenshots.gd docs/screenshots README.md tests/test_opening_presentation.gd
git commit -m "docs: add runtime opening screenshots"
git push origin codex/opening-presentation
```

## Task 7: Run regression and deliver

**Files:**
- Modify: only files required to correct an observed regression from Tasks 2–6.

**Interfaces:**
- Produces: a pushed `codex/opening-presentation` branch and recorded verification evidence.

- [ ] **Step 1: Run every Godot suite**

Run all `tests/test_*.gd` scripts and record the final `*: PASS` line. If persistence tests cannot write `user://`, report that environmental boundary and run them in an approved isolated writable environment; never modify save behavior merely to hide it.

- [ ] **Step 2: Run static and pipeline gates**

```sh
node tools/validate_content.mjs
(cd tools/lpc-factory && npm test)
(cd tools/audio-pipeline && npm test)
```

Expected: zero content errors/warnings, 21 LPC tests pass, and 10 audio tests pass.

- [ ] **Step 3: Re-capture, inspect, and confirm diff scope**

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --path . --script tools/capture_opening_screenshots.gd
git status --short
git diff --check
git log --oneline main..codex/opening-presentation
```

Expected: the worktree contains only intended opening-presentation changes and the main checkout retains the user’s separate `project.godot` change.

- [ ] **Step 4: Commit any regression-only repair and push**

```sh
git commit -m "fix: stabilize opening presentation regression"
git push origin codex/opening-presentation
```

- [ ] **Step 5: Report delivery evidence**

Report branch, commit SHAs, final command outputs, and the three screenshot paths. Do not claim completion until every applicable gate has its expected final PASS line.

