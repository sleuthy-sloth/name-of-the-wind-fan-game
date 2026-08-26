# Scene & Data Templates

How to extend the game with new content using data and scenes rather than
global-system rewrites (GDD Phase 2 exit criterion). Every section lists the
files to copy, the shape of the data, and how it reaches gameplay.

Validate everything before committing:

```sh
node tools/validate_content.mjs
```

## Adding a second location (the Phase 2 exit test)

A new playable area needs **no engine changes**:

1. Author `maps/<location>.ldtk` and a wrapper scene
   `scenes/world/<location>.tscn` whose root has an `LdtkLoader`-built level,
   a `Player`, and one or more `SceneDoor` areas for entry/exit
   (see `scenes/world/forest_campsite.tscn` as the reference).
2. Add ambience/music entries to the audio pipeline requirements if needed
   (`tools/audio-pipeline/metadata/requirements.json`) — gameplay only ever
   plays logical IDs from `audio/audio-manifest.json`.
3. Wire NPCs into it purely through data: give each NPC a schedule override
   (see [NPC schedules](#npc-schedules)) pointing at the new scene.
4. Register the location in story flow by adding beats to
   `data/story/slice_flow.json` (or a future flow file) that set/require flags.

## Quests (`data/quests/*.json`)

Copy `data/quests/quest_act1_camp_duties.json` as a template.

```json
{
  "quest_id": "quest_act1_example",
  "title": "Example",
  "stages": [
    {
      "stage_id": "stage_first",
      "objectives": [
        {"objective_id": "obj_flag", "type": "flag", "flag": "flag_some_event"},
        {"objective_id": "obj_item", "type": "item", "item": "item_lute_string", "count": 2},
        {"objective_id": "obj_rel", "type": "relationship", "character": "char_abenthy", "min": 3.0}
      ],
      "on_complete": {
        "set_flags": ["flag_next_beat"],
        "relationships": [{"character": "char_abenthy", "delta": 1.0}],
        "reputation": [{"group": "edema_ruh", "delta": 5}],
        "start_quests": ["quest_follow_up"]
      }
    }
  ]
}
```

- Stages complete in order; when every objective of a stage is satisfied the
  next stage evaluates immediately (chainable instant stages).
- Gameplay never polls quests: call `QuestManager.notify_flag(id)`,
  `notify_item(id, count)`, or change relationships through the
  RelationshipManager and objectives re-evaluate via signals.
- Runtime state persists automatically: quest progress lives in
  `GameState.quest_states[quest_id]`.

## NPC schedules (`data/schedules/*.json`)

Each file is an array of entries; see `data/schedules/troupe_schedules.json`.

```json
{
  "npc_id": "char_abenthy",
  "default": {"scene": "res://scenes/world/forest_campsite.tscn", "marker": "marker_wagon"},
  "overrides": [
    {"when": {"time_blocks": ["morning"]}, "marker": "marker_workbench"},
    {"when": {"days": [7]}, "hide": true},
    {"when": {"acts": [1], "flags": ["flag_met_player"]}, "scene": "res://scenes/world/caravan_route.tscn"}
  ]
}
```

- Time blocks are `morning | afternoon | evening | night`.
- Within one `when`: keys AND, listed values OR; last matching override wins;
  overrides may change `scene` and/or `marker` or set top-level `"hide": true`.
- Query with `ScheduleSystem.resolve_now(npc_id)` from scene scripts.
- `npc_id` must exist in a roster file (`data/characters/*.json`).

## Relationships & reputation

Use the RelationshipManager autoload instead of touching GameState dicts:

```gdscript
RelationshipManager.adjust_relationship("char_abenthy", 2.0)
RelationshipManager.adjust_reputation("edema_ruh", 5)
RelationshipManager.tier_of("char_abenthy")            # hostile|cold|neutral|warm|close
RelationshipManager.reputation_standing("edema_ruh")   # shunned|distrusted|unknown|respected|celebrated
```

Relationship values clamp to [-100, 100]; changes emit signals that quests
listen to. Dialogue effects (`relationship`, `set_flag`) keep working and now
also drive quest objectives.

## Minigames

New minigames implement three things and nothing else:

```gdscript
extends Node
signal finished(result: Dictionary)          # host consumes this
func get_minigame_id() -> String: return "minigame_my_game"
func setup(params: Dictionary) -> void: ... # optional
```

Launch through the shared host (CanvasLayer, group `minigame_host`):

```gdscript
var host: MinigameHost = MinigameHost.find_host(get_tree().root)
host.start("res://scenes/minigames/my_game.tscn", {"difficulty": 2})
host.minigame_finished.connect(_on_minigame_done)
```

The host refuses concurrent games, frees the game node on finish, and emits
`minigame_finished(id, result)` / `minigame_cancelled(id)`.

## Save data

- Bump `SAVE_VERSION` in `scripts/systems/save_manager.gd` **and** add a
  migration callable `_migrations[old] = _migrate_vN_to_vM`; loading migrates
  stepwise, saves newer than current fail closed.
- Systems needing their own persisted state join the `save_contributors`
  group and implement `save_state_id()`, `collect_save_state()`,
  `apply_save_state(d)`. Their state lands under `payload.managers[id]`.

## Conventions

- Stable `<type>_<name>_<variant>` ids everywhere (`quest_…`, `stage_…`,
  `obj_…`, `flag_…`, `char_…`); prefer adding ids over renaming.
- All creative content original or licensed per CONTRIBUTING.md.
