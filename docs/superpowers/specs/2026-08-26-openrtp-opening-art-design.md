# OpenRTP Opening Art Direction Design

## Goal

Replace the opening slice's generic Zelda-like terrain and primitive drawn
camp props with a properly licensed pixel-art art package. OpenRTP provides the
shared playable-map base, while complementary CC0 packs cover wagon-specific,
atmospheric wilderness, and urban-prologue needs. The caravan route and forest
campsite should read as authored places while preserving all existing
navigation, collision, entities, dialogue, save state, and story flow.

## Chosen source and license

Use the local package downloaded by the project owner:

- Source: `Open RPG Fantasy Tilesets` by finalbossblues
- Source URL: `https://finalbossblues.itch.io/openrtp-tiles`
- Local source: `/Users/spkoehl/Downloads/openRPG_Tilesets_5.24.22/`
- Files: `world.png`, `exterior.png`, `interior.png`, `dungeon.png`,
  `ship.png`, and `ReadMe.txt`
- Grid: 16×16 pixels
- License: CC0, confirmed by the package's `ReadMe.txt`

Copy the unmodified source PNGs and license text into
`art/tilesets/openrtp/`. Add a short provenance file that records the source
URL, local package version/date, upstream filenames, SHA-256 hashes, tile
size, and CC0 status. No book-derived or AI-generated art is introduced.

Import the following additional CC0 sources with the same provenance standard:

| Source | Repository destination | Role |
| --- | --- | --- |
| Pixel Gloomy Fantasy Tileset by Loota | `art/tilesets/gloomy_fantasy/` | 32×32 distant wilderness/backdrop layers only; never mixed into a 16×16 collision tile layer. |
| Frontier Wagons by zwonky | `art/props/frontier_wagons/` | Caravan wagon sprites, with nearest-neighbor scaling/palette grading for the opening camp. |
| Kenney RPG Urban Pack | `art/tilesets/kenney_rpg_urban/` | 16×16 Tarbean-road montage behind the existing narration scene. |

Each source retains its original image(s), upstream license text or captured
license evidence, SHA-256 hashes, source URL, creator, download date, and a
record of the scene(s) in which it is used. All four selected sources are CC0.

## Visual direction

The opening should look like an illustrated, low-fantasy journey rather than a
prototype map:

- **Caravan route:** varied dirt track, grass and flower scatter, forest edge,
  rocks, fence/bridge details, camp tents, wood-and-canvas wagons, crates, and
  a contained fire ring.
- **Forest campsite:** a smaller warm clearing with dense tree mass, irregular
  ground edges, firelight props, wagon parking, tents, beds/rolls, and a clear
  visual path through the playable space.
- **Waystone/title:** retain the existing Chronicle Canvas presentation in this
  pass. It has a separate illustrated-page style and must not be mixed with
  the OpenRTP in-world tile art.
- **Tarbean road:** use Kenney's urban tiles behind the existing narration as
  a dark, rain-muted city edge. It is a self-contained vignette rather than a
  new playable map.
- **Wilderness depth:** use Gloomy Fantasy only as distant scenery behind the
  16×16 playable map. Its 32×32 source scale remains visible at half the
  camera depth, so it adds atmosphere without implying a false tile grid.

The map scale stays at 16×16. This preserves movement feel and all LDtk
collision coordinates, while the richer tile variety removes the flat blocks
and construction-paper silhouettes visible in the present screenshots.

## Architecture

### Asset boundary

Each third-party source occupies its own `art/` directory alongside its
provenance record; no file is renamed or overwritten. A focused tool under
`tools/` defines named source regions for the caravan-specific props. The tool
is deterministic and produces project-owned composite sprites under
`art/generated/opening_art/`; each generated file carries its source tile
coordinates and source-pack identifier in the provenance record.

### Map boundary

Keep the current LDtk `IntGrid`, Spawn, Door, and Interaction entities
unchanged. Re-author only `Ground` and `Props` tile layers in
`maps/caravan_route.ldtk` and `maps/forest_campsite.ldtk`, and point their
tileset definitions to `art/tilesets/openrtp/world.png` and/or
`art/tilesets/openrtp/exterior.png`. The map tool owns every tile-index
translation so map JSON does not acquire hand-edited magic values.

### Presentation boundary

`CaravanPresentation` and a new `ForestPresentation` continue to be
visual-only: neither may add collision, move the player, change a trigger, or
write save state. Their opaque primitive wagons, tents, trees, and campfire
are replaced with source-backed composite sprites and low-cost atmosphere.
`TarbeanRoadCanvas` is similarly visual-only behind narration. Map-authored
props provide the environment; presentation props add depth without duplicating
game logic.

## Required deliverables

1. Four source-pack imports and CC0 provenance records under their dedicated
   `art/` directories.
2. Deterministic map/composite-art generation tool with an explicit tile atlas
   mapping and an error for a missing source sheet or invalid source region.
3. Re-authored caravan and campsite `Ground`/`Props` layers with all existing
   collision and entity data byte-for-byte preserved.
4. Source-backed caravan and forest visual presentations with no procedural
   rectangle, polygon, or circle art for the former wagon, tent, tree, or fire
   assets; a Gloomy Fantasy distant backdrop; and a Kenney-backed Tarbean
   narration canvas.
5. Regression coverage proving the source license records, map tileset paths,
   retained entity/collision data, generated presentation textures, and visual
   non-interference contract.
6. New real-runtime 1280×720 caravan, campsite, and Tarbean screenshots in
   the README, generated with the existing graphical screenshot workflow.

## Failure handling and validation

- Asset import fails closed with a clear source-file or checksum error.
- The map generator validates every named atlas region against the source
  image's 16×16 grid before writing output.
- Tests compare normalized collision and entity payloads before/after visual
  re-authoring, so art work cannot silently change traversal or story routing.
- Godot import refresh runs after new textures/resources are added, then the
  opening, pipeline, traversal, combat-puzzle, and slice-polish suites run.
- Screenshot capture remains graphical because headless Godot uses a dummy
  viewport with no readable texture.

## Out of scope

- Replacing LPC player/NPC character sheets, portraits, UI artwork, the
  Chronicle Canvas, music, or the Waystone scene.
- Changing tile grid size, player scale, collisions, scene paths, triggers,
  dialogue, cutscene timing, saves, or gameplay balance.
- Adding unverified, non-CC0, book-derived, or generative-AI source art.

## Acceptance criteria

- Caravan and campsite no longer use `zeldalike_overworld.png`.
- The opening camp contains authored-looking tree, tent, wagon, fire, and
  ground details using the documented CC0 packs only, with each pack used in
  its defined role rather than interleaved tile-by-tile.
- No existing story route, interaction, collision, or save-schema test regresses.
- Provenance is present and auditable directly in the repository.
- README displays committed 1280×720 runtime captures of the upgraded caravan,
  campsite, and Tarbean scenes.
