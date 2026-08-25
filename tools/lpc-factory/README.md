# LPC Sprite Factory

Automated LPC (Liberated Pixel Cup) sprite pipeline for the Name of the Wind
fan game. Assembles game-ready character and weapon sheets from the official
[Universal LPC Spritesheet Character Generator](https://github.com/sanderfrenken/Universal-LPC-Spritesheet-Character-Generator)
assets, with declarative YAML definitions, deterministic palette recoloring,
and full licensing/attribution tracking.

## Layout

- `definitions/characters/*.yaml` — declarative character recipes
- `definitions/weapons/*.yaml` — weapon recipes (variant + animations)
- `palettes/notw-*.json` — custom NOTW color ramps (body/hair/cloth)
- `scripts/lib/` — Node pipeline libraries
  - `png-compositor.mjs` — pngjs-based recolor + alpha compositing + sheet assembly
  - `resolver.mjs` — upstream asset path resolution (flat / full-sheet / variant layouts)
  - `palettes.mjs` — palette loading + native-ramp detection
  - `composer.mjs` — manifest builder (definition -> resolved images + recolor specs)
  - `credits.mjs` / `report.mjs` — attribution + build reports
- `upstream/universal-lpc/` — cloned upstream repo (gitignored; pin: commit pinned in metadata indexes)
- `metadata/` — generated asset/animation/license indexes from upstream
- `build/<name>/` — per-build output (sheet PNG, frame JSON, CREDITS.md, report)

## Usage

```bash
cd tools/lpc-factory
npm install                # js-yaml + pngjs
node scripts/inspect-lpc.mjs            # regenerate metadata indexes (after upstream update)
node scripts/build-character.mjs definitions/characters/factory_test.yaml --publish
node scripts/build-weapon.mjs definitions/weapons/lpc_sword_test.yaml --publish
```

`--publish` copies the sheet PNG + JSON + credits into `art/sprites/lpc/`.

## Definition format (character)

```yaml
name: kvothe
bodyType: male            # male|female|teen|child|muscular|pregnant
animations: [idle, walk]
layers:
  - { item: body.body_color,     color: swarthy,     palette: notw-body }
  - { item: hair.long_messy,     color: kvothe_rust, palette: notw-hair }
  - { item: clothes.longsleeve,  color: ruh_green,   palette: notw-cloth }
  - { item: legs.pants,          color: tarbean_brown }
  - { item: shoes.basic_boots }                       # default upstream ramp
```

- `item` must be an id from `metadata/asset-index.json` (657 items indexed).
- `color` is a named ramp in the material palette; the compositor detects which
  native upstream ramp the sprite pixels actually use and remaps shade-by-shade.
- `palette` optionally selects a factory palette from `palettes/`
  (`notw-cloth.json` etc.); otherwise the upstream material palette is used.
- `variant` selects weapon/material variants (e.g. `iron`, `steel`).

## Recoloring model

LPC sprites are painted with one named 6-shade ramp per material
(dark→light). Detection scores every named ramp in the source palette by how
many of its shades appear as pixels; the best match becomes the mapping
source. Target ramps come from the same file or a NOTW factory palette.
This means sprites can be recolored to any named ramp without hand-painting.

## Output JSON

`<name>.json` contains a TexturePacker-style `frames` map keyed
`<animation>_<dir>_<frame>` plus `meta.animations` summarizing row offsets,
frames/directions/frameSize per animation. Directions are rows ordered
up/left/down/right (LPC standard).

## Licensing

Every build emits `CREDITS.md` aggregating authors/licenses/URLs from the
upstream `sheet_definitions` credit blocks for exactly the items used.
License families present upstream: OGA-BY, CC-BY, CC-BY-SA, CC0, GPL-2/3.
Respect them when distributing; see repo CONTRIBUTING.md.
