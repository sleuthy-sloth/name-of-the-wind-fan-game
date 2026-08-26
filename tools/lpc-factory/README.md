# LPC Sprite Factory

Automated LPC sprite-sheet pipeline for NOTW characters, weapons, and NPC
crowds. Pure Node (`pngjs`) composition and recoloring — no Aseprite CLI
dependency. See `AGENTS.md` for environment quirks.

## Setup

```sh
cd tools/lpc-factory
npm install            # js-yaml + pngjs
node scripts/update-lpc.mjs          # clone/fetch upstream at the pinned commit
node scripts/inspect-lpc.mjs         # (re)generate metadata/*-index.json
```

## CLI reference

| Command | Purpose |
| --- | --- |
| `node scripts/update-lpc.mjs [--check] [--pin <ref>] [--main]` | Sync `upstream/universal-lpc` to the pinned commit recorded in `metadata/asset-index.json`. Rerun `inspect-lpc` after changing pins. |
| `node scripts/build-character.mjs <char.yaml> [--animations idle,walk] [--publish]` | Build one character: definition → validation → manifest → compose/recolor → sheet PNG+JSON → CREDITS.md → build-report.json |
| `node scripts/build-weapon.mjs <weapon.yaml> [--publish]` | Same pipeline for single-item weapon sheets. |
| `node scripts/generate-npcs.mjs <archetype\|name> [--count N] [--seed S] [--build] [--publish]` | Deterministic pool-based NPC generation from `definitions/npc-archetypes/*.yaml` into `definitions/generated/`; `--list` shows archetypes. |
| `node scripts/build-group.mjs <group.yaml\|name> [--publish]` | Build every member of a `definitions/groups/*.yaml` batch; writes `build/groups/<name>/group-report.json` + merged CREDITS.md. |
| `node scripts/build-all.mjs [--only <substr>] [--check] [--publish]` | Build all characters/weapons/generated defs; aggregate report at `build/build-all-report.json`. Fails non-zero if any build fails. |
| `node scripts/validate-build.mjs <name>\|--all [--quiet]` | Verify a build dir: manifest parses, sheet PNG matches JSON meta.size, frame rects in bounds, every resolved animation present, opaque pixels > 0, credits exist. |
| `node scripts/generate-credits.mjs [--check]` | Aggregate attribution for ALL definitions into repo-root `CREDITS/LPC-CREDITS.txt` + `.csv`. CI-friendly with `--check`. |

Typical full run:

```sh
npm test                                   # unit tests (no upstream needed)
node scripts/generate-npcs.mjs ruh_crew --build
node scripts/build-all.mjs
node scripts/validate-build.mjs --all
node scripts/generate-credits.mjs --check
```

## Definition formats

Character (`definitions/characters/*.yaml`):

```yaml
name: factory_test
bodyType: male              # male|female|teen|child|muscular|pregnant
animations: [idle, walk]
layers:
  - item: body.body_color   # catalog id from metadata/asset-index.json
    color: light            # recolor-capable items: upstream or custom palette name
  - item: clothes.longsleeve
    color: ruh_green
    palette: notw-cloth     # custom target palette in palettes/notw-cloth.json
  - item: clothes.tunic
    variant: gray           # variant-dir items use variants instead of colors
```

Weapon (`definitions/weapons/*.yaml`): `{ name, item, bodyType, variant,
color?, animations }`.

NPC archetype (`definitions/npc-archetypes/*.yaml`):

```yaml
name: ruh_crew
count: 4
seed: 20260825              # any value; drives deterministic picks
bodyTypes: [male, female]
animations: [idle, walk]
slots:                      # ordered; exactly one layer per slot per NPC
  - slotName: hair
    pool:
      - item: hair.page
        colors: [black, brown]      # recolor item -> color; variant item -> variant
      - item: hair.balding
```

Group (`definitions/groups/*.yaml`):

```yaml
name: smoke_group
members:
  - definitions/characters/factory_test.yaml
  - definitions/generated/ruh_crew_00.yaml
```

## Output layout

- `build/<name>/<name>.png|.json` — game-ready sheet + texture-atlas JSON
  (`frames["<anim>_<dir>_<f>"]`, `meta.animations[<anim>] = {row,y,frames,
  directions,frameSize}`)
- `build/<name>/manifest.json`, `CREDITS.md`, `build-report.json`
- `build/groups/<name>/group-report.json`, `CREDITS.md`
- `../../art/sprites/lpc/` — published sheets when `--publish` is passed

`npm test` runs `node --test "tests/**/**.test.mjs"` (definition parsing,
validator rules, palette math, NPC determinism, credit aggregation). Tests
are hermetic — they read `metadata/asset-index.json` but never touch upstream
PNGs.

## Pending custom assets

Roster definitions build cleanly from upstream LPC parts, but several NOTW
signatures need original art before they're screen-final:

| Item | Current stand-in | Needed |
| --- | --- | --- |
| Caesura | `weapon.saber` (steel) | Curved blade with notched/broken guard |
| Kvothe's lute (prop) | none | Held lute prop layer for idle/performance |
| Haliax's shadowed face | hood + pale skin | Face-shadow overlay layer |
| Cinder's aura | glowsword blue only | Cold-blue rim light / frost overlay |
| University masters' robes | longsleeve recolors | Distinct robe silhouettes with hoods |
| Adem costume | generic longsword carrier | Adem red ribbon + fitted silhouette |
