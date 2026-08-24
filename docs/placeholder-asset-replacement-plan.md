# Placeholder Asset Replacement Plan

This document inventories every placeholder asset currently used in *The Name of the Wind: The Kingkiller Chronicle* vertical slice and defines the path to final production assets. Placeholders are labeled in code, scene files, and data where possible so they can be swapped without rewriting systems.

## Characters

| Asset | Current File | What It Is | Final Asset | Priority |
|---|---|---|---|---|
| Player sprite | `art/sprites/kvothe_placeholder_sheet.png` | Protagonist sprite sheet; currently a solid-color block-out used by `scenes/player/player.tscn`. | Hand-drawn Kvothe sprite sheet with idle, walk, lute-hold, and Sympathy-casting frames. | High |
| Player in-scene representation | `scenes/player/player.tscn` | Uses a `GradientTexture2D` sub-resource for the Sprite2D node. | Replace with `Sprite2D.texture` referencing the final Kvothe sprite sheet and add an AnimationPlayer. | High |
| Abenthy NPC | `scenes/npcs/abenthy.tscn` | Instances the generic `Npc` scene with Abenthy's dialogue path; uses the default placeholder sprite/color. | Custom Abenthy sprite/portrait and a dedicated interaction animation. | High |
| Troupe member 01 (Sera) | `scenes/npcs/troupe_member_01.tscn` | Generic NPC instance with Sera's metadata. | Final sprite and portrait for Sera, the tanner's apprentice. | Medium |
| Troupe member 02 (Pip) | `scenes/npcs/troupe_member_02.tscn` | Generic NPC instance with Pip's metadata. | Final sprite and portrait for Pip, the wagon mender. | Medium |
| Generic NPC base | `scenes/npcs/npc.tscn` | Base scene with a placeholder collision shape and no final art. | Keep as a template; replace default sprite with a fallback traveler silhouette. | Medium |

## Environments

| Asset | Current File | What It Is | Final Asset | Priority |
|---|---|---|---|---|
| Caravan route map | `maps/caravan_route.ldtk` | LDtk level with simple tile shapes and a spawn/door marker. | Authored caravan-route tileset (road, wagons, trees, sky) with parallax background. | High |
| Forest campsite map | `maps/forest_campsite.ldtk` | LDtk level defining the camp layout with placeholder tiles. | Final forest campsite tileset (tents, campfire, wagons, foliage) and lighting overlay. | High |
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
| Music tracks | `audio/` (empty except `.gitkeep`) | No music implemented yet. | Original traveling/caravan themes, tense attack cue, and aftermath ambience. | High |
| Lute note tones | Generated in `scripts/minigames/sympathy_lighting.gd` | Synthesized sine-wave tones used as feedback. | Recorded lute samples or carefully synthesized plucks mapped to note lanes. | High |
| Sympathy feedback tones | Generated in `scripts/minigames/sympathy_lighting.gd` | Synthesized tones for light/heat domain feedback. | Themed Sympathy hum/burn sounds with distinct light and heat signatures. | Medium |
| UI sounds | None | No UI audio yet. | Button click, hover, error, save/load, and scene-transition sounds. | Medium |
| Ambience | None | No environmental ambience yet. | Forest/campfire ambience, wagon creaks, wind, and attack silence cue. | Medium |

## Maps

| Asset | Current File | What It Is | Final Asset | Priority |
|---|---|---|---|---|
| LDtk project data | `maps/*.ldtk` | LDtk source files with placeholder tile layers and entity markers. | Final LDtk projects referencing the production tilesets and entity art. | High |
| Tileset textures | Embedded in LDtk / generated | Simple colored tiles used for collision and layout. | Production 16x16 or 32x32 pixel-art tilesets for roads, camps, forests, and interiors. | High |
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
