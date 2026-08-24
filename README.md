<div align="center">

# THE NAME OF THE WIND

### *The Kingkiller Chronicle* — An Unofficial Fan Game

**A 2D top-down narrative RPG / life sim about what knowledge costs.**

![Engine](https://img.shields.io/badge/engine-Godot%204.7-478CBF?logo=godot-engine&logoColor=white)
![Code License](https://img.shields.io/badge/code%20license-MIT-blue)
![Asset License](https://img.shields.io/badge/assets%20CC%20BY--NC--SA%204.0-lightgrey)
![Platform](https://img.shields.io/badge/platform-PC%20%7C%20Keyboard%20%2B%20Controller-black)
![Status](https://img.shields.io/badge/status-Phase%200%20—%20Foundation-orange)

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

🚧 **Phase 0 — Foundation.** The vertical slice target is Act I: a 45–90
minute playable journey from caravan life to the Chandrian attack.

| Phase | Goal | Status |
|---|---|---|
| 0 — Foundation | Engine shell: movement, scenes, save/load, debug overlay | ✅ Complete |
| 1 — Vertical slice | Act I: Edema Ruh — music, Sympathy, the attack | ⏳ Planned |
| 2 — Architecture pass | Data-driven quests, schedules, reputation | ⏳ Planned |
| 3 — Tarbean prototype | Survival loop: hunger, warmth, stealth | ⏳ Planned |
| 4 — University core | Life-sim hub: classes, tuition, Fishery, Eolian | ⏳ Planned |
| 5 — Full narrative | Complete scope, polish, accessibility, release build | ⏳ Planned |

---

## Core systems

- **Four-block days** — Morning / Afternoon / Evening / Night. Most actions
  cost one block; big commitments cost two.
- **Sympathy** — a three-slot working bench (`SOURCE → LINK → TARGET`) with
  legible energy, risk, and slippage. Experimentation teaches even on failure.
- **Lute performance** — a rhythm minigame graded on timing, continuity,
  expression, and recovery. Results change payment, reputation, and fatigue.
- **Reputation** — five bands per faction, moved by visible actions.
- **Threat resolution, not combat** — flee, hide, talk, or spend a prepared
  resource. Physical conflict is short, authored, and consequential.
- **Alar** — mental stamina spent on magic, study, and composure; restored
  through sleep, food, and safe company.

---

## Built with

| Tool | Role |
|---|---|
| [Godot 4](https://godotengine.org) | Engine & GDScript gameplay |
| [LDtk](https://ldtk.io) | Authored maps, collision & intention layers |
| [Aseprite](https://www.aseprite.org) | Pixel art & animation |
| Git | Version control |
| [Kenney](https://kenney.nl) & itch.io CC assets | Placeholder audio/SFX during prototyping |

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

Open `project.godot` in Godot and press **F5** (a playable main scene lands
with Phase 0's first milestone).

### Project layout

```
├── scenes/        # core, player, npcs, ui, minigames, locations
├── scripts/       # systems, dialogue, quests, minigames, tools
├── data/          # characters, items, recipes, workings, schedules, dialogue
├── art/           # Aseprite sources & exported sheets
├── audio/         # music beds, SFX, stems
├── maps/          # LDtk projects
├── docs/          # design documents (GDD lives here)
├── tests/         # automated checks for pure logic
└── addons/        # editor plugins (e.g. LDtk importer)
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

---

<div align="center">

*"It's like everyone tells a story about themselves inside their own head.
Always. All the time. That story makes you what you are. We build ourselves
out of the stories that we tell."*

</div>
