# Development Guide

This guide covers how to run **The Name of the Wind: The Kingkiller Chronicle**
locally, execute its headless test suites, and navigate the project's systems.
For contribution rules see [CONTRIBUTING.md](../CONTRIBUTING.md); for the full
design see [The-Name-of-the-Wind-GDD.md](The-Name-of-the-Wind-GDD.md).

## Overview

This project is an unofficial, non-commercial fan game based on *The Kingkiller
Chronicle* by Patrick Rothfuss — a 2D top-down narrative RPG / life sim built
in Godot 4.7. Completed so far: Phase 0 (engine foundation), Phase 1 (Edema
Ruh vertical slice, tasks 1.1–1.8), the art/audio integration pass, an LPC
sprite factory (`tools/lpc-factory/`), a licensed audio pipeline
(`tools/audio-pipeline/`), and the Phase 2 modular architecture pass
(data-driven quests, schedules, relationships/reputation, minigame host,
save migrations — see [templates.md](templates.md) for authoring new content).
All creative content must remain original; see
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
Project). The main scene is `res://scenes/world/waystone_inn.tscn`, a scripted
opening at the Waystone Inn (frame story: Kote and Bast) that sets
`waystone_opening_seen` and routes into Act I on `caravan_route.tscn`.

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

Sixteen suites are `SceneTree` scripts run without a window. Each prints a
`*_TEST: PASS` or `*_TEST: FAIL` line and exits with status `0` (pass) or `1`
(fail). After adding `class_name` scripts, refresh the global class cache
first:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/spkoehl/Documents/OpenCode/The Name of The Wind" --import
```

| Suite | Script | What it proves |
| --- | --- | --- |
| ENGINE_SHELL_TEST | `tests/test_engine_shell.gd` | Input map, player movement, scene routing, door transitions. |
| PIPELINE_TEST | `tests/test_pipeline.gd` | LDtk parsing, IntGrid collision, spawn metadata. |
| SAVE_LOAD_TEST | `tests/test_save_load.gd` | GameState round-trip, slot persistence, corrupt-save handling. |
| DIALOGUE_TEST | `tests/test_dialogue.gd` | Dialogue validation, effects, NPC wiring. |
| PHASE0_EXIT_TEST | `tests/test_phase0_exit.gd` | Integrated GDD §23 exit criteria. |
| WORLD_TRAVERSAL_TEST | `tests/test_world_traversal.gd` | Caravan/camp maps and traversal. |
| INVENTORY_ECONOMY_TEST | `tests/test_inventory_economy.gd` | Inventory, money, HUD data flow. |
| LUTE_PERFORMANCE_TEST | `tests/test_lute.gd` | Lute charts, scoring, stage flow. |
| SYMPATHY_TEST | `tests/test_sympathy.gd` | Sympathy engine energy/risk formulas, bench UI. |
| SYMPATHY_LIGHTING_TEST | `tests/test_sympathy_lighting.gd` | Palette-swap lighting response. |
| ROSTER_DIALOGUE_TEST | `tests/test_roster_dialogue.gd` | Troupe roster + tagged-choice tutorial dialogue. |
| CHANDRIAN_ATTACK_TEST | `tests/test_chandrian_attack.gd` | Attack sequence beats and aftermath flags. |
| VERTICAL_SLICE_TEST | `tests/test_vertical_slice_integration.gd` | GDD §24 slice checklist end-to-end. |
| PHASE2_ARCH_TEST | `tests/test_phase2_architecture.gd` | Quest lifecycle, relationship tiers, schedule resolution, minigame host, save v1→v2 migration. |
| SLICE_POLISH_TEST | `tests/test_slice_polish.gd` | Published LPC sheets, animated wiring, schedules, ambience, tint, prompts. |
| COMBAT_PUZZLE_TEST | `tests/test_combat_puzzles.gd` | ThreatEncounter four resolutions, SympathyPuzzle workings, SympathyTarget world effects, Waystone opening, tutorial content. |

Tool pipelines have their own Node test suites:
`cd tools/lpc-factory && npm test` (21 tests) and
`cd tools/audio-pipeline && npm test` (10 tests). Static content checks:
`node tools/validate_content.mjs`.

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
metadata. Tileset/entity support landed in Phase 1.

### QuestManager (autoload)

Data-driven quests from `data/quests/*.json`. Objectives come in three
types (`flag`, `item`, `relationship`); stages complete in order and chain
instantly. Gameplay reports events via `notify_flag/notify_item` and through
RelationshipManager signals; rewards apply `set_flags`, relationship and
reputation deltas, and follow-on quests.

### RelationshipManager (autoload)

Typed API over `GameState.relationships` / `GameState.reputation`: clamped
adjustments, tier queries (`hostile…close`, `shunned…celebrated`), and change
signals consumed by quests.

### ScheduleSystem (autoload)

Resolves where an NPC is per act/day/time-block from
`data/schedules/*.json`, with flag-conditional overrides and hide support.
Scene scripts call `resolve_now(npc_id)`.

### MinigameHost

Reusable CanvasLayer lifecycle for skill minigames: games expose a
`finished(result)` signal plus optional `setup(params)`; the host handles
launch, exclusivity, teardown, and result/cancel signals.

### SaveManager v2

Versioned JSON slots with stepwise migrations (`_migrations[1]` upgrades v1
payloads) and a `save_contributors` group so subsystems persist their own
state under `payload.managers`. Saves newer than `SAVE_VERSION` fail closed.

### BeatCutscene

Generic data-driven narration cutscene: `{ id, beats: [{narration, effect,
duration, set_flag, sfx, next_scene, autosave}] }` from any JSON path. Drives
the Waystone Inn opening (`scenes/world/waystone_inn.tscn`, the project main
scene) and is reusable for future scripted scenes. Works headless — overlay
and label nodes are optional.

### ThreatEncounter

Threat resolution per GDD §7.5 — the game's replacement for conventional
combat. A threat definition offers up to four resolutions: **flee** (route
choice with risk), **hide** (timing window), **talk** (gated on reputation or
a relationship), and **sympathy** (resolved through SympathyEngine at real
Alar cost; composure drops as pressure rises). Failed attempts escalate
`pressure`; hitting `pressure_limit` ends the encounter in forced failure.
Definitions live in `data/threats/*.json`; `flags_for()` maps outcomes to
world flags. Presented in-game by `ThreatPanel`
(`scripts/ui/threat_panel.gd`). The playable tutorial lives at
`scenes/world/combat_tutorial.tscn` (reachable through the campsite's east
door): Abenthy's lesson dialogue, then the ford-carter encounter where all
four doors open. Completion sets `flag_threat_tutorial_done`.

### SympathyPuzzle / SympathyTarget

Out-of-combat sympathy workings (GDD §8 applied to the world): open stuck
doors/hatches and move jammed obstacles. A puzzle def pins link, target, and
effect while offering a choice of energy sources (`data/workings/*.json`) —
weaker sources raise Alar cost and risk through the shared engine formulas.
`SympathyTarget` (Area2D) exposes the interactable in world scenes via
WorldScene's `sympathy_targets` export and applies the committed working:
`open_door` disables/fades its barrier, `move_obstacle` tweens it aside, then
the success flag lands in GameState. `SympathyPuzzlePanel` renders the
prompt, source choice, and live cost/risk preview.

## Conventions

- **Stable IDs.** Content identifiers follow `<type>_<name>_<variant>` — e.g.
  `char_abenthy`, `quest_act1_abenthy_lesson`,
  `flag_act1_chandrian_attack_seen`. Prefer adding a new ID over renaming an
  existing one; renames require updating every reference.
- **Original assets only.** All art, audio, prose, and design must be original
  or properly licensed. See the ground rules in
  [CONTRIBUTING.md](../CONTRIBUTING.md).

## Session memory protocol

Cross-session progress and consistency are handled by the holographic memory
MCP store (persistent SQLite with trust scoring), enforced via `AGENTS.md`:

1. **Session start** — recall project state
   (`holographic_memory_search("Name of the Wind status")`), check
   `git log --oneline -5`, then resume from `.swarm/plan.json`.
2. **After every completed task/milestone** — push a short fact
   (`holographic_memory_add`, category `project`, tag `name-of-the-wind`).
3. **Session end, even mid-task** — push progress + exact next step.

Correct or supersede stale facts instead of accumulating duplicates; keep
facts under ~500 characters; never store secrets.
