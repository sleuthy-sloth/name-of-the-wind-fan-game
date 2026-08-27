# Placeholder Asset Replacement Plan

This document inventories every placeholder asset currently used in *The Name of the Wind: The Kingkiller Chronicle* vertical slice and defines the path to final production assets. Placeholders are labeled in code, scene files, and data where possible so they can be swapped without rewriting systems.

## Characters

| Asset | Current File | What It Is | Final Asset | Priority |
|---|---|---|---|---|
| Player sprite | `art/sprites/zeldalike_character.png` | CC0 sprite sheet (ArMM1998); 17×16 grid of 16px tiles with directional walk frames. Wired in `scenes/player/player.tscn` with region-enabled Sprite2D and directional switching in `player.gd`. | Hand-drawn Kvothe sprite sheet with idle, walk, lute-hold, and Sympathy-casting frames. | High |
| Player in-scene representation | `scenes/player/player.tscn` | Uses `Sprite2D` with `region_enabled` referencing `zeldalike_character.png`; `player.gd` switches `region_rect` by movement direction. | Replace with final Kvothe sprite sheet and add an AnimationPlayer. | High |
| Abenthy NPC | `scenes/npcs/abenthy.tscn` | Instances `npc.tscn` with Abenthy's dialogue path; uses `zeldalike_npc.png` row 0 with a purple tint (`modulate`). | Custom Abenthy sprite/portrait and a dedicated interaction animation. | High |
| Troupe member 01 (Sera) | `scenes/npcs/troupe_member_01.tscn` | NPC instance with Sera's metadata; uses `zeldalike_npc.png` row 2 with a warm tint. | Final sprite and portrait for Sera, the tanner's apprentice. | Medium |
| Troupe member 02 (Pip) | `scenes/npcs/troupe_member_02.tscn` | NPC instance with Pip's metadata; uses `zeldalike_npc.png` row 4 with a green tint. | Final sprite and portrait for Pip, the wagon mender. | Medium |
| Generic NPC base | `scenes/npcs/npc.tscn` | Base scene with collision, interaction area, and `Sprite2D` using `zeldalike_npc.png` (region-enabled, row 0 default). | Keep as a template; replace default sprite with a fallback traveler silhouette. | Medium |

## Environments

| Asset | Current File | What It Is | Final Asset | Priority |
|---|---|---|---|---|
| Caravan route map | `maps/caravan_route.ldtk` | LDtk level with IntGrid collision, Ground/Props Tiles layers using `zeldalike_overworld.png` (CC0), and Spawn/Door/Interaction entities. | Authored caravan-route tileset (road, wagons, trees, sky) with parallax background. | High |
| Forest campsite map | `maps/forest_campsite.ldtk` | Expanded 40×28-tile LDtk tutorial level with arrival road, central clearing, north lesson grove, south return trail, OpenRTP Ground/Props layers, collision barriers, and camp entities. | Final forest campsite tileset (tents, campfire, wagons, foliage) and lighting overlay. | High |
| Caravan blockout | `maps/test_caravan_blockout.ldtk` | Early geometric block-out for layout testing. | Replace with the final caravan-route art or remove once the real map is validated. | Low |
| Campfire source (Sympathy) | Created at runtime by `scripts/minigames/sympathy_lighting.gd` | `ColorRect` placeholder representing the campfire source for light/heat workings. | Final campfire sprite/particle effect with palette-swap support. | Medium |
| Lamp target (Sympathy) | Created at runtime by `scripts/minigames/sympathy_lighting.gd` | `ColorRect` placeholder representing the lamp target for light/heat workings. | Final lamp/prop sprite with modulate-driven brightening. | Medium |

## UI

| Asset | Current File | What It Is | Final Asset | Priority |
|---|---|---|---|---|
| HUD | `scenes/ui/hud.tscn` | Placeholder HUD layout for time, Alar, money, and flags. | Final HUD skin with Edema Ruh caravan theming, readable typography, and status icons. | High |
| End card | `scenes/ui/end_card.tscn` | Placeholder vertical-slice end card. | Illustrated end card with the aftermath text and forward-momentum hook. | High |
| Lute stage | `scenes/minigames/lute_stage.tscn` | Placeholder note highway and timing feedback UI. | Final lute fretboard/neck visual, note gems, hit feedback particles, and grade screen. | High |
| Sympathy bench | `scenes/minigames/sympathy_bench.tscn` | Placeholder source/link/target slots using `ColorRect` blocks. | Final Sympathy workbench UI with draggable objects, bind rune visuals, and cost/risk readouts. | High |
| Sympathy lighting demo | `scenes/minigames/sympathy_lighting_demo.tscn` | Demo scene for palette-swap lighting response. | Final version integrated into the campsite with proper props and overlays. | Medium |
| Dialogue box | Built in `scripts/systems/dialogue_runner.gd` | Panel, labels, and buttons created in code with default theme. | Themed dialogue panel with speaker portraits and choice buttons. | High |
| Debug overlay | `scripts/systems/debug_overlay.gd` | Development-only overlay; not player-facing. | Keep as a debug tool; no final art required. | Low |

## Audio

| Asset | Current File | What It Is | Final Asset | Priority |
|---|---|---|---|---|
| Music tracks | `audio/music/` (Kenney CC0 jingles) | Pizzicato jingle wired into `end_card.tscn`; 8-Bit/Sax/Steel/Hit jingles staged for future use. | Original traveling/caravan themes, tense attack cue, and aftermath ambience. | High |
| Lute note tones | `audio/sfx/lute_*.ogg` (synthesized) | 8 Karplus-Strong synthesized lute notes (D3–A4) wired into `lute_stage.gd` and `sympathy_lighting.gd` with generator fallback. | Recorded lute samples or carefully synthesized plucks mapped to note lanes. | High |
| Sympathy feedback tones | `audio/sfx/lute_*.ogg` + generator fallback | Lute samples used for light (A4) and heat (D3) domain feedback in `sympathy_lighting.gd`. | Themed Sympathy hum/burn sounds with distinct light and heat signatures. | Medium |
| UI sounds | `audio/sfx/` (Kenney CC0) | `select_001.ogg` on scene change, `click_002.ogg` on dialogue advance, `switch_002.ogg` on money change (throttled). | Button click, hover, error, save/load, and scene-transition sounds. | Medium |
| Ambience | `audio/ambience/` (synthesized) | `campfire_loop.ogg` (30s brown-noise+crackle) in forest_campsite, `forest_night_loop.ogg` (30s wind+cricket) in caravan_route. | Forest/campfire ambience, wagon creaks, wind, and attack silence cue. | Medium |

## Maps

| Asset | Current File | What It Is | Final Asset | Priority |
|---|---|---|---|---|
| LDtk project data | `maps/*.ldtk` | LDtk source files with IntGrid collision, Ground/Props Tiles layers (zeldalike_overworld.png CC0), and entity markers. | Final LDtk projects referencing the production tilesets and entity art. | High |
| Tileset textures | `art/tilesets/zeldalike_overworld.png` (CC0) | 640×576 pixel-art tileset (40×36 tiles at 16px) used for Ground and Props layers. | Production 16x16 or 32x32 pixel-art tilesets for roads, camps, forests, and interiors. | High |
| Scene-transition fade | `scripts/systems/scene_router.gd` | Plain black `ColorRect` fade. | Optional: subtle travel wipe or caravan-themed transition once art is ready. | Low |

## Replacement Timeline

Aligned with the production roadmap in `docs/The-Name-of-the-Wind-GDD.md` §23:

- **Phase 1 exit (vertical slice lock):** Replace player sprite, Abenthy portrait/sprite, HUD, lute stage UI, Sympathy bench UI, and the two main LDtk maps with first-pass final art. All placeholders must be labeled in this document.
- **Phase 2 (modular architecture pass):** Finalize troupe-member NPC sprites, dialogue UI, end card, and environmental props. Remove or archive block-out maps.
- **Phase 3+ (Tarbean and beyond):** Replace remaining low-priority placeholders and add full audio pass. No placeholder should remain in a public build.

## Naming and Workflow Conventions

- Final art files use the same base names as placeholders where possible (e.g., `kvothe_placeholder_sheet.png` becomes `kvothe_sheet.png`) to minimize scene edits.
- Scene files keep placeholder nodes named clearly (e.g., `PlaceholderSprite`, `ColorRect`) so artists can find them.
- New placeholder assets added during prototyping must be added to this table before merging.
