<div align="center">

# THE NAME OF THE WIND

### *The Kingkiller Chronicle* — An Unofficial Fan Game

**A 2D top-down narrative RPG / life sim about what knowledge costs.**

![Engine](https://img.shields.io/badge/engine-Godot%204.7-478CBF?logo=godot-engine&logoColor=white)
![Code License](https://img.shields.io/badge/code%20license-MIT-blue)
![Asset License](https://img.shields.io/badge/assets%20CC%20BY--NC--SA%204.0-lightgrey)
![Platform](https://img.shields.io/badge/platform-PC%20%7C%20Keyboard%20%2B%20Controller-black)
![Status](https://img.shields.io/badge/status-In%20Development-orange)

</div>

> *What will Kvothe sacrifice to keep learning, keep performing, and keep
> moving toward the truth about the Chandrian?*

---

## About

You play the early life of Kvothe: gifted performer, relentless student, and
increasingly desperate survivor. You do not grow powerful by collecting bigger
weapons — you grow powerful by learning how the world works, making hard
tradeoffs, and applying knowledge under pressure. Every advantage has a cost:
time, money, fatigue, reputation, health, or personal safety.

This is an unofficial, **non-commercial** fan adaptation. It is not affiliated
with, endorsed by, or authorized by Patrick Rothfuss or any rights holder.
All code, art, music, and writing are original. See [Legal](#legal--disclaimers).

### Three acts, three identities

| Act | Life stage | Primary verbs | Emotional texture |
|---|---|---|---|
| **I. The Edema Ruh** | Childhood and first awakening | Travel, perform, learn, trust | Wonder, belonging, discovery |
| **II. Tarbean** | Trauma and survival | Hide, beg, endure, remember | Fear, deprivation, isolation |
| **III. The University & Imre** | Adolescence and ambition | Study, work, craft, compete, investigate | Agency, rivalry, obsession |

### Design pillars

- **Knowledge is power, but knowledge costs time.**
- **Music is an action, not decoration** — performance changes money,
  reputation, relationships, and access.
- **Magic is strict, legible, and dangerous** — Sympathy follows visible
  rules: pick a *source*, a *link*, and a *target*, and pay the cost.
- **Scarcity creates drama, not busywork.**
- **Authored moments carry the canon.**
- **Small-team sustainability** — data-driven systems, reusable patterns,
  clear cut lines.

---

## Current status

🚧 **Act I vertical slice playable end-to-end, in polish.** Phase 0
(engine foundation), Phase 1 (Edema Ruh vertical slice, tasks 1.1–1.8) and
Phase 2 (modular architecture: data-driven quests, schedules,
relationships/reputation, minigame host, save migrations) are complete and
covered by automated headless suites. The slice now opens with a scripted
Waystone Inn prologue (frame story with Kote and Bast, plus a walkable inn
interior), teaches threat resolution through a playable combat tutorial, and
closes with a post-slice epilogue — surviving the ruined camp alone via a
sympathy friction-fire working, then the road to Tarbean.

| Phase | Goal | Status |
|---|---|---|
| 0 — Foundation | Engine shell: movement, scenes, save/load, dialogue, NPC interaction, LDtk pipeline | ✅ Complete |
| 1 — Vertical slice | Act I: Edema Ruh — music, Sympathy, the attack | ✅ Complete (polish ongoing) |
| 2 — Architecture pass | Data-driven quests, schedules, reputation | ✅ Complete |
| 3 — Tarbean prototype | Survival loop: hunger, warmth, stealth | ⏳ Planned |
| 4 — University core | Life-sim hub: classes, tuition, Fishery, Eolian | ⏳ Planned |
| 5 — Full narrative | Complete scope, polish, accessibility, release build | ⏳ Planned |

Automated verification: **16 Godot headless suites** (engine shell, LDtk
pipeline, save/load, dialogue, sympathy engine + lighting, lute stage,
inventory/economy, roster, world traversal, Chandrian attack, phase-0 exit,
integrated vertical slice, slice polish, phase-2 architecture, threat,
puzzles, settings, credits & chronicler's journal) plus unit-tested asset
pipelines for sprites and audio. Run instructions live in
[`docs/development.md`](docs/development.md).

---

## Core systems

- **Four-block days** — Morning / Afternoon / Evening / Night. Most actions
  cost one block; big commitments cost two.
- **Sympathy** — a three-slot working bench (`SOURCE → LINK → TARGET`) with
  legible energy, risk, and slippage. Experimentation teaches even on failure.
  The same rules work out in the world: split a rain-cracked boulder off the
  track, open a swollen hatch, light a cold lamp, or kindle a fire to survive
  the night — your choice of energy source sets the Alar cost and risk.
- **Lute performance** — a rhythm minigame graded on timing, continuity,
  expression, and recovery. Results change payment, reputation, and fatigue.
- **Reputation** — five bands per faction, moved by visible actions.
- **Threat resolution, not combat** — flee by route choice, hide by timing,
  talk when your standing earns it, or resolve it with a sympathy working at
  real Alar cost. Failed attempts escalate pressure until things go badly;
  Abenthy's tutorial teaches all four doors, and threats appear out on the
  road. Physical conflict is short, authored, and consequential.
- **Chronicler's Journal** — auto-recorded in Chronicler's voice the moment
  things happen: a story tab for each event, a map tab with fog of war that
  lights as you wander, and an items tab. Press **J** from anywhere.
- **Accessibility** — per-category volume (Master / Music / Ambience / SFX),
  font scale, reduce motion, colorblind-safe threat palette. Open from the
  title menu or the end card.
- **Alar** — mental stamina spent on magic, study, and composure; restored
  through sleep, food, and safe company.

---

## Sprite art pipeline

Character and weapon art is generated by an automated **LPC Sprite Factory**
(`tools/lpc-factory/`) built on the [Universal LPC Spritesheet Character
Generator](https://github.com/sanderfrenken/Universal-LPC-Spritesheet-Character-Generator)
asset set (657 indexed items). Characters are declared in YAML — body type,
animations, equipment items, palette colors — and the factory resolves every
sprite layer, recolors it by detecting which native 6-shade LPC ramp the pixels
use, alpha-composites the stack, and emits a game-ready sheet plus JSON frame
data and a per-build `CREDITS.md` with exact upstream attribution.

```bash
cd tools/lpc-factory && npm install

# index upstream assets (after updating the upstream pin)
npm run lpc:inspect

# build a character / weapon and copy into art/sprites/lpc/
node scripts/build-character.mjs definitions/characters/factory_test.yaml --publish
node scripts/build-weapon.mjs definitions/weapons/lpc_sword_test.yaml --publish
```

Custom story palettes live in `tools/lpc-factory/palettes/notw-*.json`
(e.g. Ruh green, University blue, Chandrian black) and are selected per layer
with `palette:` in a definition. See
[`tools/lpc-factory/README.md`](tools/lpc-factory/README.md) for the full
definition format and pipeline details.

---

## Audio pipeline

Game audio is managed by a licensed acquisition & publishing pipeline,
`tools/audio-pipeline/`, with one rule above all: **every asset's license is
verified at its source and every file is traceable** — no rips, no
"royalty-free" vibes, no unattributed CC-BY. Assets flow strictly:

```
DOWNLOAD -> SOURCE ARCHIVE -> LICENSE VALIDATION -> CANDIDATE ->
PROCESS -> AUDIO REVIEW -> PUBLISH -> GAME ASSETS
```

- **Licensing tiers** — CC0 preferred; CC-BY allowed with stored attribution;
  CC-BY-SA / OGA-BY / GPL quarantined for review; NC / ND / unclear /
  unknown rejected outright.
- **Provenance** — `metadata/licenses.json` records creator, source URL,
  download date and license per asset, backed by evidence files in
  `sources/licenses/` and untouched originals in `sources/original/`.
  `CREDITS/AUDIO-CREDITS.txt/.csv` are generated from it.
- **Event-driven runtime** — gameplay never loads audio files directly. The
  pipeline publishes `audio/audio-manifest.json`, mapping logical IDs
  (`SFX_PAGE_TURN`, `MUS_UNIVERSITY_DAY`, `AMB_TARBEAN_NIGHT`) to variant
  pools, and the static `AudioLibrary` class rotates variants per event.
  Assets can be replaced without touching game code.
- **Review gating** — music (and signature sounds: Sympathy, Naming,
  Chandrian, lute performances) publish only after an explicit human
  approval recorded in the registry; everything else still needs a clean
  license validation to ship.
- **Processing** — FFmpeg loudness normalization per category (music /
  ambience / SFX), OGG Vorbis output with lossless sources preferred, WAV
  fallback for latency-sensitive samples; originals are never modified.

```bash
cd tools/audio-pipeline

npm test                       # policy + metadata invariants
npm run audio:index            # validate registry <-> files, coverage report
npm run audio:validate         # enforce license tiers
npm run audio:normalize -- --all   # FFmpeg -> processed/
npm run audio:publish          # approved assets -> audio/ + manifest
npm run audio:credits          # regenerate CREDITS/AUDIO-CREDITS.*
```

Current coverage: **144 logical requirements catalogued** (18 music events,
ambience beds/layers, and full SFX families from footsteps to Sympathy);
37 filled and 7 partially filled from verified CC0/CC-BY sources
(OpenGameArt packs by artisticdude, rubberduck, TinyWorlds, plus Kenney
interface/impact/jingle sets); two music candidates sit normalized in the
review queue awaiting human approval. See
[`tools/audio-pipeline/README.md`](tools/audio-pipeline/README.md) and its
[`AGENTS.md`](tools/audio-pipeline/AGENTS.md) for the complete rules.

---

## Built with

| Tool | Role |
|---|---|
| [Godot 4](https://godotengine.org) | Engine & GDScript gameplay |
| [LDtk](https://ldtk.io) | Authored maps, collision & intention layers |
| [Aseprite](https://www.aseprite.org) | Pixel art & animation |
| [Universal LPC sprites](https://opengameart.org/content/lpc-collection) | Character/weapon bases, assembled by our sprite factory |
| Node.js | Sprite factory + audio pipeline tooling |
| FFmpeg | Audio normalization & encoding |
| Git | Version control |
| [Kenney](https://kenney.nl), [OpenGameArt](https://opengameart.org) CC0/CC-BY assets | Licensed production audio via our audio pipeline |

---

## Getting started

### Prerequisites

- **Godot 4.7+** (standard build, no .NET required)
- *(content authoring)* LDtk 1.5+, Aseprite — only needed to edit maps/art

### Run

```bash
git clone https://github.com/sleuthy-sloth/name-of-the-wind-fan-game.git
cd name-of-the-wind-fan-game
```

Open `project.godot` in Godot and press **F5**, or run headless from the
command line — controls, suite commands, and architecture notes are in
[`docs/development.md`](docs/development.md).

### Project layout

```
├── scenes/        # core, player, npcs, ui (incl. title menu, settings, credits,
│                  #   journal), minigames, locations, world
├── scripts/       # systems (incl. AudioLibrary, SliceDirector, ThreatEncounter,
│                  #   SympathyEngine, SympathyPuzzle, ChroniclerJournal,
│                  #   ExplorationMap, Settings), dialogue, quests, minigames
├── data/          # characters, items, recipes, workings, schedules, dialogue,
│                  #   journal (scene registry), threats, stories, items, charts
├── art/           # Aseprite sources & exported sheets (incl. generated lpc/)
├── audio/         # event-organized production audio + audio-manifest.json
├── maps/          # LDtk projects
├── docs/          # design documents (GDD lives here)
├── tests/         # 16 headless Godot test suites
├── CREDITS/       # generated audio credits (AUDIO-CREDITS.txt/.csv)
├── addons/        # editor plugins (e.g. LDtk importer)
└── tools/         # build tooling — lpc-factory sprites, audio-pipeline sound
```

---

## Contributing

Read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening a PR. Short version:
original work only, stable content IDs, small reviewable changes, and no
monetization — ever.

## Legal & disclaimers

- **Unofficial fan work.** Not affiliated with, endorsed by, or authorized by
  Patrick Rothfuss, DAW Books, Penguin Random House, or any rights holder.
  All rights to *The Kingkiller Chronicle* belong to their owners. Full
  statement in [`NOTICE.md`](NOTICE.md).
- **Code:** [MIT License](LICENSE). **Art, audio, maps & writing:**
  [CC BY-NC-SA 4.0](LICENSE-ASSETS.md).
- Distributed free of charge. If a rights holder objects, the project comes
  down promptly.

## Acknowledgements

- **Patrick Rothfuss** — for the world that inspired this project.
- **The Godot, LDtk, Aseprite & Kenney communities** — for extraordinary
  tools available to everyone.
- **The Liberated Pixel Cup community** — and every artist credited in the
  Universal LPC asset set our sprite factory builds from. Per-item
  attribution is emitted with every generated sheet; license terms are
  respected in full.

---

<div align="center">

*"It's like everyone tells a story about themselves inside their own head.
Always. All the time. That story makes you what you are. We build ourselves
out of the stories that we tell."*

</div>
