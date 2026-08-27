# Opening Presentation Design

## Goal

Turn the first five minutes of *The Name of the Wind* into a visually authored
vertical-slice opening: a Chronicler's-page title screen, a skippable Waystone
prologue, and a richly dressed caravan scene that becomes the first moment of
player control.  The work also produces reproducible runtime screenshots for
the GitHub README.

## Product Decisions

- The title screen is a living Chronicler's page, not a conventional fantasy
  menu. It uses parchment, ink, quill, wax-seal, firelight, and restrained page
  movement.
- The Waystone is a non-playable, illustrated framing sequence. It must not
  place the player in the unfinished `waystone_inn_interior.tscn`.
- The final prologue beat routes directly to the caravan opening.
- The caravan becomes the first playable location. It must read as an Edema Ruh
  camp through original set dressing and atmosphere rather than as a generic
  overworld tileset.
- All new creative work is original, generated in-engine, or carries a
  compatible, documented license. Nothing may reproduce book prose or use
  unverified art.
- Gameplay screenshots must come from the running project, be committed in
  `docs/screenshots/`, and be displayed from the repository README.

## Presentation Architecture

### ChronicleCanvas

Create a reusable `Control`-based renderer for presentation-only Chronicle
imagery. Its public surface is intentionally small:

```gdscript
class_name ChronicleCanvas
extends Control

enum Illustration { TITLE_PAGE, WAYSTONE_FIRE, CARAVAN_DAWN }

@export var illustration: Illustration = Illustration.TITLE_PAGE
@export var animate: bool = true

func set_illustration(value: Illustration) -> void
func render_signature() -> Dictionary
```

`_draw()` renders the parchment field, border, ink marks, and the selected
original illustration from deterministic shapes and colors. `render_signature()`
returns the selected illustration, page dimensions, and a count of the visual
layers so tests can assert that title/prologue surfaces are not blank. The
component reads `/root/Settings`: reduce-motion disables drifting particles and
page movement, while the existing font-scale option continues to govern text
outside the canvas.

### Title scene

`title_menu.tscn` gains a `ChronicleCanvas` behind the current controls and a
small visible label identifying the game as an unofficial fan game. The menu
keeps Godot's native button focus/navigation behavior. `title_menu.gd` handles
only UI wiring, audio, save state, and the canvas's animation preference; it
does not contain drawing code.

### Waystone prologue

`waystone_inn.tscn` gains a `ChronicleCanvas` in `WAYSTONE_FIRE` mode behind
the existing narration layer. The existing six-beat data flow, skip behavior,
and autosave remain unchanged. The final beat in `data/story/waystone_opening.json`
changes its `next_scene` to `res://scenes/world/caravan_route.tscn`.

`waystone_inn_interior.tscn` remains in the repository but is not reachable
from the opening. It is explicitly deferred until it has a complete environment
and a meaningful interaction loop.

### Caravan presentation

Create a `CaravanPresentation` `Node2D` component that provides original visual
set dressing around the LDtk terrain: distant tree silhouettes, a layered
canopy, wagons, tents, a central campfire, ground shadows, and low-motion ember
or leaf particles. It renders behind/around gameplay entities without changing
collision, spawn, door, quest, schedule, or threat data.

`WorldScene` gets one optional exported `presentation_scene: PackedScene` and
instances it before player/NPCs. `caravan_route.tscn` assigns the caravan
presentation; other locations retain their current behavior. The component must
be deterministic when animations are disabled so screenshots are stable.

### Interaction feedback

The first playable caravan pass standardizes critical interactions. NPCs,
threats, and Sympathy targets receive the same focused prompt treatment:

- interaction prompt includes the active binding label rather than a hardcoded
  `[E]` where that label is available;
- a soft outline/halo appears while in range;
- interaction plays existing approved UI feedback;
- world-changing actions show a short, readable acknowledgement before control
  returns.

This work must not change narrative outcomes, economy values, threat rules, or
save schema.

## Screenshot and Documentation Pipeline

Create `tools/capture_opening_screenshots.gd`, a deterministic SceneTree script
that loads the title, Waystone prologue, and caravan scenes in a fixed state and
writes PNG captures at 1280×720 to `docs/screenshots/`:

- `title-chronicle.png`
- `waystone-prologue.png`
- `caravan-dawn.png`

The script fails non-zero if a scene cannot load, the viewport image is not
1280×720, or a PNG cannot be written. It does not read or modify player save
slots. `README.md` receives a concise Screenshot section with relative images
and a command for regenerating them. Generated PNGs are committed because they
are reviewable project documentation and GitHub must render them directly.

## Tests and Acceptance Criteria

Add a focused Godot suite for the opening presentation. It must verify:

1. title and Waystone scenes contain a `ChronicleCanvas` with the expected
   illustration mode;
2. reduce-motion disables ChronicleCanvas animation;
3. the Waystone final beat routes to `caravan_route.tscn`;
4. caravan scene assigns its presentation scene and it exposes the required
   visual layer nodes;
5. interaction prompt text can resolve from an input action binding; and
6. the screenshot script is present and declares the three expected outputs.

The test is written first and observed failing before production code is added.
Existing Godot suites, `node tools/validate_content.mjs`, the LPC factory tests,
and audio-pipeline tests remain required regression gates. Persistence tests are
run only in an environment with an isolated writable `user://` directory.

## Delivery and Git

Implementation happens in a new `codex/opening-presentation` worktree based on
the current committed `main`, excluding the user's uncommitted `project.godot`
change. Commits are small and thematic:

1. `docs: define opening presentation direction`
2. `feat: add chronicle title and waystone prologue art`
3. `feat: dress caravan opening and interaction feedback`
4. `docs: add runtime opening screenshots`

After all verification passes, the branch is pushed to the configured GitHub
remote. No user-authored uncommitted file is staged, altered, or included.

## Scope Boundary

This milestone makes the opening credible and establishes reusable visual
language. It does not build a complete playable Waystone Inn, Tarbean,
University content, voice acting, a new save format, or a replacement for every
existing placeholder in the game.
