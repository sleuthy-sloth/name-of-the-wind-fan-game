# Development Guide

This guide covers how to run **The Name of the Wind: The Kingkiller Chronicle**
locally, execute its headless test suites, and navigate the Phase 0 systems.
For contribution rules see [CONTRIBUTING.md](../CONTRIBUTING.md); for the full
design see [The-Name-of-the-Wind-GDD.md](The-Name-of-the-Wind-GDD.md).

## Overview

This project is an unofficial, non-commercial fan game based on *The Kingkiller
Chronicle* by Patrick Rothfuss — a 2D top-down narrative RPG / life sim built
in Godot 4.7. Phase 0 (repository and engine foundation) is complete: the
project shell, core state systems, save/load, scene routing, dialogue, NPC
interaction, and an LDtk map pipeline are implemented and covered by five
headless test suites. All creative content must remain original; see
[CONTRIBUTING.md](../CONTRIBUTING.md) for the provenance ground rules.

## Prerequisites

| Tool | Version | Notes |
| --- | --- | --- |
| [Godot](https://godotengine.org) | 4.7+ | Engine and editor. On this machine the binary lives at `/Applications/Godot.app/Contents/MacOS/Godot`. |
| [LDtk](https://ldtk.io) | 1.5+ | Level editor used for maps (`maps/*.ldtk`). Content authoring only. |
| [Aseprite](https://www.aseprite.org) CLI | current | Sprite authoring. Content authoring only — not needed to run or test the game. |

> The project directory path contains spaces (`The Name of The Wind`). Always
> quote paths in shell commands.

## Running the game

Open the project in Godot (select `project.godot`), then press **F5** (Run
Project). The main scene is `res://scenes/core/placeholder_test_a.tscn`, a
placeholder room with walls, a player, and a door that transitions to
`placeholder_test_b.tscn`.

From the command line:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --path "/Users/spkoehl/Documents/OpenCode/The Name of The Wind"
```

### Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move | W/A/S/D or arrow keys | Left stick |
| Interact | E | A (bottom face button) |
| Pause | Esc | Start |
| Debug overlay | F3 | — |

F3 toggles the debug overlay (act/day/time block, Alar, money, world-flag
count, current scene). It is handled directly by the `DebugOverlay` autoload,
not through the input map.

## Headless test suites

All five suites are `SceneTree` scripts run without a window. Each prints a
`*_TEST: PASS` or `*_TEST: FAIL` line and exits with status `0` (pass) or `1`
(fail).

### Import step (required after adding `class_name` scripts)

New `class_name` scripts (e.g. `LdtkLoader`, `DialogueRunner`) are resolved
through Godot's global script class cache. After adding or renaming such
scripts, refresh the cache before running the suites:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/spkoehl/Documents/OpenCode/The Name of The Wind" --import
```

### Suites

| Suite | Command | What it proves |
| --- | --- | --- |
| ENGINE_SHELL_TEST | `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/spkoehl/Documents/OpenCode/The Name of The Wind" --script res://tests/test_engine_shell.gd` | Input map registers all six actions; the player moves under simulated input; both placeholder scenes load and instantiate; `SceneRouter.change_scene()` lands on `PlaceholderTestB`; a body entering the `player` group triggers a `SceneDoor` transition. |
| PIPELINE_TEST | `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/spkoehl/Documents/OpenCode/The Name of The Wind" --script res://tests/test_pipeline.gd` | `LdtkLoader.load_project()` parses `maps/test_caravan_blockout.ldtk`; `build_level_node()` generates the IntGrid collision bodies (≥ 50 shapes) and exposes a `spawn_position` meta inside level bounds; the placeholder sprite sheet exists at 64×32. |
| SAVE_LOAD_TEST | `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/spkoehl/Documents/OpenCode/The Name of The Wind" --script res://tests/test_save_load.gd` | `GameState` defaults (act 1, Alar 100, money 0); `to_dict()`/`from_dict()` round-trips all fields; `SaveManager.save_game()`/`load_game()` persist and restore state (post-save mutations revert); a corrupt slot file fails cleanly instead of crashing. |
| DIALOGUE_TEST | `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/spkoehl/Documents/OpenCode/The Name of The Wind" --script res://tests/test_dialogue.gd` | The Abenthy lesson dialogue passes `DialogueRunner.validate()` with zero errors; a full walkthrough applies the relationship and `set_flag` effects and emits `dialogue_finished`; deliberately broken data produces a missing-reference error; the NPC scene loads with a valid attached script. |
| PHASE0_EXIT_TEST | `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/spkoehl/Documents/OpenCode/The Name of The Wind" --script res://tests/test_phase0_exit.gd` | Integrated GDD §23 Phase 0 exit criteria: move, talk (NPC interaction drives dialogue effects), save, mutate-and-load restores prior state, and world flags survive a scene transition. |

## Architecture

Phase 0 ships seven building blocks. Autoloads are registered in
`project.godot`; the remaining systems live under `scripts/systems/`,
`scripts/tools/`, and `scenes/`.

### GameState (autoload)

Session-state spine: `act`, `day`, `time_block`, Alar (`alar`/`max_alar`),
and `money`, plus dictionaries for `relationships` (character id → float),
`reputation` (group → int), `quest_states` (quest id → state), and
`world_flags` (flag id → true). `set_flag()`/`has_flag()` manage flags;
`to_dict()`/`from_dict()` provide the serialization boundary used by saves
and tests.

### SaveManager (autoload)

Versioned JSON slots written to `user://saves/slot_<n>.json`. Each payload
stores `version`, `saved_at`, the serialized GameState dictionary, and the
current `scene_path`. Loading rejects corrupt JSON and any `version` mismatch
rather than guessing. When serialized fields change, bump `SAVE_VERSION` and
add a migration step — older saves fail closed until migrated.

### SceneRouter (autoload)

Owns scene changes behind a 0.2-second black fade-out/fade-in. An
`is_transitioning` guard ignores requests made mid-transition, preventing
double transitions when several triggers overlap.

### SceneDoor

An `Area2D` with a `target_scene` export. On `body_entered`, any body in the
`player` group is routed through `SceneRouter.change_scene()`.

### DialogueRunner

CanvasLayer-driven dialogue UI fed by structured JSON data (`dialogue_id`,
`root`, `nodes`). The static `validate()` performs content checks per GDD
§21.3/§22.2: required `root`/`nodes`, unknown `next` and choice references,
empty text on non-end nodes, and malformed effects. Supported effects are
`relationship` (target + delta) and `set_flag`. End nodes hide the UI and
emit `dialogue_finished(dialogue_id)`.

### Npc scene

A `StaticBody2D` with exported `npc_id`, `display_name`, and `dialogue_path`.
Its `InteractionArea` tracks whether a `player`-group body is in range;
`interact()` reads the dialogue JSON, runs `validate()`, and starts a
`DialogueRunner` only if the data is clean.

### LdtkLoader

Phase 0 minimal reader (IntGrid collision + Spawn only):
`load_project()` parses and sanity-checks an `.ldtk` file;
`build_level_node()` converts IntGrid cells marked `1` into `StaticBody2D`
collision shapes and exposes the `Spawn` entity position as `spawn_position`
metadata. Full tileset/entity support lands in Phase 1.

## Conventions

- **Stable IDs.** Content identifiers follow `<type>_<name>_<variant>` — e.g.
  `char_abenthy`, `quest_act1_abenthy_lesson`,
  `flag_act1_chandrian_attack_seen`. Prefer adding a new ID over renaming an
  existing one; renames require updating every reference.
- **Original assets only.** All art, audio, prose, and design must be original
  or properly licensed. See the ground rules in
  [CONTRIBUTING.md](../CONTRIBUTING.md).
