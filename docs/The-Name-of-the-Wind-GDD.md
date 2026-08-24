# The Name of the Wind: The Kingkiller Chronicle

## Comprehensive Game Design Document

**Working title:** *The Name of the Wind: The Kingkiller Chronicle*  
**Project type:** Noncommercial, unofficial fan-game  
**Genre:** 2D top-down narrative RPG / life sim  
**Primary platform:** PC first; keyboard/mouse and controller support  
**Engine recommendation:** Godot 4  
**Target development model:** Solo creator with AI-assisted design, scripting, testing, and content tooling  
**Document status:** Production-facing design baseline  

> This is an unofficial, noncommercial fan project. It is not affiliated with, endorsed by, or authorized by the rights holders. The project should use original code, original pixel art, original music, and properly licensed third-party assets only. Distribution plans must be reviewed against applicable rights and platform policies.

---

## 1. High Concept

The player inhabits the early life of Kvothe: a gifted performer, relentless student, and increasingly desperate survivor. The game follows his movement from the Edema Ruh, through the trauma of Tarbean, into the competitive academic world of the University and Imre.

The player does not become powerful by collecting increasingly large weapons. They become powerful by learning how the world works, making difficult tradeoffs, and applying knowledge under pressure. Every advantage has a cost: time, money, fatigue, reputation, health, or personal safety.

The central question is:

> What will Kvothe sacrifice to keep learning, keep performing, and keep moving toward the truth about the Chandrian?

The game is structured as three acts with deliberately different emotional and mechanical identities:

| Act | Life stage | Primary verbs | Emotional texture |
|---|---|---|---|
| I. The Edema Ruh | Childhood and first awakening | Travel, perform, learn, trust | Wonder, belonging, discovery |
| II. Tarbean | Trauma and survival | Hide, beg, endure, remember | Fear, deprivation, isolation |
| III. The University and Imre | Adolescence and ambition | Study, work, craft, compete, investigate | Agency, rivalry, obsession |

The full game is the north star. Act I is the only committed production target until its vertical-slice acceptance criteria are met.

---

## 2. Product Definition

### 2.1 Player experience

The intended experience is a focused single-player story in which the player:

- explores compact, authored environments rather than a massive open world;
- makes choices that alter immediate opportunities, relationships, and costs;
- learns systems through diegetic instruction and experimentation;
- uses music, intelligence, and magic as equally important forms of expression;
- feels scarcity without being trapped by opaque punishment;
- sees Kvothe’s abilities grow while his risks and obligations grow with them.

### 2.2 Audience

The primary audience is players who enjoy narrative RPGs, life sims, light stealth, rhythm games, crafting puzzles, and literary fantasy. The game assumes familiarity with the setting is welcome but not required; major terms should be introduced through play rather than an encyclopedia dump.

### 2.3 Content and tone

The game deals with grief, violence, poverty, hunger, homelessness, coercion, addiction, and trauma. Tarbean should be distressing without becoming exploitative. The experience should include content warnings and options for reducing screen shake, flashing effects, harsh audio, and depictions of abuse.

### 2.4 Platform and session design

- PC-first release target.
- 16:9 baseline with scalable UI for 16:10 and ultrawide displays.
- Typical session length: 20–60 minutes.
- Save anywhere outside of active minigames and scripted crisis sequences.
- Autosave at major story beats, act transitions, tuition resolution, and before irreversible decisions.

### 2.5 Scope boundaries

The project is intentionally not:

- a full open-world adaptation;
- a conventional party-based combat RPG;
- a complete adaptation of unresolved future-book mysteries;
- a voice-acted cinematic game;
- a multiplayer or live-service product;
- a procedural story generator;
- a simulation of every day of Kvothe’s life.

The game should represent selected, meaningful moments and the systems surrounding them. Unshown time is compressed through travel, montage, or time advancement.

---

## 3. Design Pillars

### Pillar 1: Knowledge is power, but knowledge costs time

The player solves problems by learning relationships between systems. Studying, experimenting, and listening unlocks options, but those activities consume time and Alar. The best solution is often unavailable because the player chose another priority earlier.

### Pillar 2: Music is an action, not decoration

Performance changes money, reputation, relationships, and access. Music should feel physically demanding and emotionally expressive, not like a collectible side activity.

### Pillar 3: Magic is strict, legible, and dangerous

Sympathy behaves according to understandable rules. Players should be able to predict why a working succeeded or failed. Mystery comes from the world and from Naming, not from arbitrary UI outcomes.

### Pillar 4: Scarcity creates drama, not busywork

Money, warmth, hunger, time, and fatigue should force decisions. They should not require constant menu maintenance or produce unwinnable states. The game must provide recovery routes, even when those routes are unpleasant.

### Pillar 5: Authored moments carry the canon

The game uses systemic play to make the player feel involved, but major canon events remain carefully authored. Systems create context, variation, and consequences around story beats; they do not randomly rewrite the core narrative.

### Pillar 6: Small-team sustainability

Every feature must be explainable in a one-page design and testable without a large content team. Data-driven systems, reusable scene patterns, and clear cut lines are more valuable than feature count.

---

## 4. Core Player Loop

### 4.1 Moment-to-moment loop

1. Enter a compact environment or scene.
2. Observe people, objects, exits, and sources of opportunity or danger.
3. Choose a verb: talk, perform, study, craft, sneak, search, work, travel, rest, or experiment.
4. Spend a resource such as time, Alar, money, health, reputation, or an item.
5. Receive information, gain access, earn a reward, or create a new problem.
6. Reassess priorities and choose the next action.

### 4.2 Daily loop

Each day is divided into four time blocks:

- Morning
- Afternoon
- Evening
- Night

Most meaningful activities consume one block. Major travel, long study sessions, performances, and certain crafting jobs consume two. The player may cancel an action before committing, but completed actions advance time immediately.

At the end of the day, the player chooses how to recover:

- sleep in a safe bed: strong recovery, costs money or access;
- sleep in an unsafe location: weak recovery, risk of interruption;
- continue working or studying: gain progress, take fatigue and risk;
- use an item or favor: immediate recovery, consumes a limited resource.

### 4.3 Full-game loop

Study, perform, survive, and investigate. The player alternates between gaining capability and paying the cost of using it. The central long-term goal is not represented by a single quest marker; it is a collection of clues, relationships, and learned rules that gradually point toward the Chandrian.

---

## 5. Narrative Structure

### 5.1 Narrative approach

The story is a curated fan adaptation of the early chronology represented in the source outline. It should preserve recognizable character roles, locations, emotional beats, and magic concepts while avoiding invented answers to mysteries that the source leaves unresolved.

The player may influence:

- how much money Kvothe has at a given moment;
- which relationships are warm, strained, or transactional;
- the order of optional University discoveries;
- the quality of performances and crafted items;
- the cost and risk of certain solutions;
- the wording and attitude of selected dialogue choices.

The player may not casually prevent the foundational events that define the three acts.

### 5.2 Act I: The Edema Ruh

**Purpose:** Tutorial and vertical slice. Establish belonging, music, curiosity, and the first concrete rules of Sympathy before shattering the player’s assumptions about safety.

**Locations:**

- traveling roads;
- forest paths;
- caravan camp;
- performance clearing;
- temporary camp after the attack.

**Primary systems:**

- movement and interaction;
- dialogue and relationship tags;
- inventory and simple resource management;
- lute performance;
- introductory Sympathy;
- authored exploration;
- cinematic crisis sequence.

**Recommended sequence:**

1. Caravan arrival and movement tutorial.
2. Small camp tasks that establish troupe life.
3. Conversation with Abenthy about observation and hidden rules.
4. First lute performance with a low-pressure chart.
5. Optional exploration of camp objects and troupe relationships.
6. Abenthy’s Sympathy lesson: source, link, target.
7. A controlled experiment involving heat or light.
8. Evening performance or camp conversation.
9. The Chandrian attack.
10. Escape, aftermath, and vertical-slice end card.

**Act I success condition:** The player understands that music, empathy, and technical knowledge are all forms of agency; the attack proves that none of them guarantees safety.

### 5.3 Act II: Tarbean

**Purpose:** Deliberate genre shift from wonder to survival. The game removes the player’s established tools so that basic human needs become the primary challenge.

**Locations:**

- slum streets;
- rooftops;
- alleys and courtyards;
- abandoned interiors;
- midwinter pageant grounds;
- hidden shelter routes.

**Primary systems:**

- hunger and warmth;
- stealth and suspicion;
- begging and social reading;
- safe locations;
- item scarcity;
- limited information and memory fragments.

Magic and music are locked away as active systems during the early trauma phase. This is a narrative constraint, not a missing feature. The player may hear remembered music or see symbolic echoes, but they cannot use performance or Sympathy to solve ordinary problems.

**Recommended sequence:**

1. Arrival and immediate loss of resources.
2. First shelter and hunger tutorial.
3. Learning the routes, threats, and social rules of Tarbean.
4. Begging, scavenging, and avoiding guards.
5. Rooftop traversal and winter exposure.
6. Repeated failure/recovery cycle that teaches persistence.
7. Midwinter Pageant and encounter with Encanis.
8. Skarpi’s story.
9. Purpose returns; Act II ends with the first meaningful forward plan.

**Act II design rule:** The player may be poor, cold, frightened, or injured, but should not be permanently soft-locked by one bad day.

### 5.4 Act III: The University and Imre

**Purpose:** The core life-sim/RPG experience. The player has more agency but must balance competing ambitions in a social and economic system that reacts to every advantage.

**Locations:**

- University grounds;
- classrooms and courtyards;
- the Archives;
- the Fishery;
- the Underthing;
- Imre streets;
- the Eolian;
- surrounding roads and Trebon.

**Primary systems:**

- four-block time management;
- semester tuition;
- admissions and social reputation;
- classes and skill advancement;
- Fishery work and artificing;
- Eolian performance;
- loans and debt;
- Archives access and risk;
- Underthing exploration;
- rivalry and dialogue states;
- limited combat/threat resolution;
- investigation board and clue tracking.

**Major climax threads:**

- conflict with Ambrose;
- Draccus encounter in Trebon;
- patron search and performance stakes;
- securing a patron as the act’s closing status change.

### 5.5 Canon and fan-project guardrails

- Use the setting as a fan adaptation, not as a claim of official canon.
- Avoid reproducing book prose verbatim in large amounts.
- Write original dialogue that evokes character roles without copying passages.
- Use original music; do not reproduce soundtrack recordings or unlicensed songs.
- Use original or licensed art, sound effects, fonts, and code.
- Do not resolve the identity of the Amyr, the Chandrian, or other long-running mysteries beyond the chosen adaptation scope.
- Preserve ambiguity where ambiguity is part of the source’s appeal.

---

## 6. Characters and Factions

### 6.1 Player character: Kvothe

Kvothe is represented through a combination of player choice and authored characterization. The player controls priorities, tone, risk tolerance, and attention. The narrative controls the major life events and the emotional consequences of those events.

Core player-facing attributes:

| Attribute | Meaning | Raised by |
|---|---|---|
| Wit | Dialogue, improvisation, pattern recognition | Conversation, observation, study |
| Sympathy | Magical control and link efficiency | Abenthy, classes, experimentation |
| Music | Timing, repertoire, expression | Practice, performance |
| Artificing | Craft quality and rune complexity | Fishery work, diagrams, class |
| Medica | Treatment knowledge and recovery efficiency | Classes, field practice |
| Stealth | Detection avoidance and route reading | Tarbean play, exploration |
| Composure | Resistance to panic and social pressure | Rest, successful crisis choices |

These are not traditional combat stats. They are access keys that open different solutions and modify risk.

### 6.2 Key characters

| Character | Function in the game | System connection |
|---|---|---|
| Abenthy | Mentor and first Sympathy teacher | Tutorial, experimentation, worldview |
| Arliden | Troupe leader and father | Caravan authority, family bond |
| Laurian | Mother and emotional anchor | Family scenes, tone, memory |
| Skarpi | Storyteller and narrative catalyst | Act II awakening, lore |
| Trapis | Shelter and compassion in Tarbean | Recovery, safe space, moral contrast |
| Devi | Creditor, rival, and technical equal | Loans, debt, knowledge exchange |
| Ambrose | Social and economic antagonist | Reputation, sabotage, escalation |
| Auri | Underthing guide and mystery figure | Exploration, trust, Naming foreshadowing |
| Simmon | Friend and academic support | Study, social recovery |
| Wilem | Friend, skeptic, and Archives access | Information, reputation |
| Kilvin | Fishery authority | Crafting rules, work progression |
| Elodin | Unpredictable teacher | Naming, player uncertainty |
| Fela | Academic peer and Fishery/social connection | Crafting, reputation, relationships |
| Elxa Dal | Advanced Sympathy instructor | High-risk magic progression |
| Lorren | Archives gatekeeper | Access, suspicion, time pressure |
| Hemme | Institutional obstacle | Class access, humiliation, reputation |
| Deoch and Stanchion | Eolian operators | Performance, talent pipes, venue access |

Characters should be implemented through reusable relationship records rather than bespoke hard-coded quest logic.

### 6.3 Factions and reputation groups

- Edema Ruh troupe
- Tarbean street network
- University faculty
- University students
- Fishery/artificers
- Archives staff
- Imre performers and patrons
- Eolian management
- Devi’s debt network

Reputation is group-specific. A player can be respected in the Fishery while disliked by faculty, or admired at the Eolian while financially desperate.

---

## 7. Core Systems

### 7.1 Movement and interaction

Movement is top-down, eight-directional, and responsive. Interactable objects use a consistent visual language:

- subtle outline or shimmer when focusable;
- short contextual verb when in range;
- optional “interaction focus” mode for controller users;
- no mandatory pixel-hunting for critical objects.

Environments are compact enough that shortcuts and landmarks matter. The player should learn spaces by use rather than by staring at a minimap.

### 7.2 Dialogue

Dialogue is choice-driven with authored reactions. Choices may carry tags such as:

- honest;
- clever;
- arrogant;
- vulnerable;
- evasive;
- Ruh-coded;
- sympathetic;
- desperate.

Tags modify relationship and reputation outcomes, but no choice should be labeled as objectively correct. Important conversations expose likely stakes before commitment. A player can inspect known relationship modifiers in the journal without seeing hidden future branches.

### 7.3 Reputation

Reputation uses a five-band scale:

| Band | State |
|---|---|
| -2 | Hostile or actively suspicious |
| -1 | Distrusted |
| 0 | Unknown/neutral |
| +1 | Recognized or tolerated |
| +2 | Trusted or favored |

Reputation affects prices, invitations, dialogue options, rumor spread, and access. Reputation should decay slowly, if at all; it is primarily changed by visible actions and meaningful conversations.

### 7.4 Inventory

Inventory categories:

- currency;
- food and warmth items;
- tools and materials;
- documents and clues;
- crafted items;
- instruments and performance aids;
- quest objects.

The inventory is intentionally small in Acts I and II. Capacity expansion arrives later through bags, storage, or location-based caches. Key story objects should never be lost through accidental selling.

### 7.5 Threat resolution instead of conventional combat

The game does not need a large enemy roster or full action-combat system. Threat scenes use one of four resolutions:

1. flee through movement and route choice;
2. hide or distract through stealth;
3. talk, deceive, or leverage reputation;
4. use a prepared item or Sympathy working at a clear cost.

Physical conflict, where unavoidable, is short, authored, and consequence-focused. The game should never require building a combat meta to finish the story.

---

## 8. Sympathy

### 8.1 Player fantasy

Sympathy allows the player to manipulate energy and outcomes by establishing a meaningful connection between things. It should feel like constructing a working hypothesis under pressure.

### 8.2 Required working structure

Every Sympathy working uses three selections:

1. **Source:** where energy comes from, such as a campfire or body heat.
2. **Link:** what establishes similarity or connection, such as a coin, ash, or blood.
3. **Target:** what receives the effect, such as a lamp, lock, object, or hazard.

The player must also choose the intended effect and, for advanced workings, the number of bindings.

### 8.3 Gameplay model

The game uses a readable abstraction rather than attempting a full physics simulation.

Define:

- `S` = source energy available;
- `L` = link quality from 0.0 to 1.0;
- `M` = player mastery from 0.0 to 1.0;
- `R` = requested effect cost;
- `T` = target tolerance;
- `D` = working difficulty.

Effective energy is calculated as:

```text
effective_energy = S × (0.5 + 0.5L) × (0.6 + 0.4M)
```

Risk is calculated as:

```text
risk = clamp((R - effective_energy) / max(R, 1), 0, 1)
risk = risk × D × (1 - composure_bonus)
```

If `R` is within the effective range and the target can accept the effect, the working succeeds. If the player exceeds the safe range, the game rolls for slippage using the visible risk value. Failure may cause:

- loss of Alar;
- physical damage;
- source depletion;
- target damage;
- unwanted attention;
- a partial or inverted effect.

The exact formulas are tunable. The important player-facing rules are that stronger sources, better links, higher mastery, and lower requested costs make workings safer.

### 8.4 Sympathy interface

The Sympathy UI is a three-slot workbench:

```text
[ SOURCE ]  →  [ LINK ]  →  [ TARGET ]  →  [ EFFECT ]
     energy        quality          tolerance        cost/risk
```

The interface displays:

- known source capacity;
- link quality;
- estimated Alar cost;
- target tolerance;
- slippage risk band;
- what will be consumed on success or failure.

The player may experiment with unknown combinations, but experimentation must teach something even on failure. The journal records discovered relationships.

### 8.5 Progression

- Act I: one-link, low-cost workings; light, warmth, and simple motion.
- Act II: no active Sympathy use during the locked phase.
- Act III early: multi-link workings, heat transfer, locks, protection, and practical Fishery applications.
- Act III late: high-risk bindings and crisis improvisation.

### 8.6 Accessibility and safety

Players may pause the working interface, view a rules summary, and reduce visual heat or screen effects. A low-stakes practice mode is available after the first lesson.

---

## 9. Music and the Lute

### 9.1 Purpose

Music is a source of identity, income, emotional expression, and social access. It is also the clearest way to make the player feel Kvothe’s talent rather than only read about it.

### 9.2 Minigame structure

The lute minigame is a short rhythm performance played against an original in-universe arrangement. Each chart contains:

- pulse;
- strum direction or note pattern;
- accent notes;
- held notes;
- rests;
- phrase endings;
- optional improvisation windows.

The player is graded on timing, continuity, expression, and recovery from mistakes. The chart should be learnable through practice rather than requiring perfect reflexes.

### 9.3 Performance results

| Result | Immediate effect |
|---|---|
| Collapse | Small payment or no payment; reputation risk |
| Passable | Basic payment; unlocks repeat opportunities |
| Strong | Better payment; positive reputation |
| Exceptional | Large tip, relationship change, special invitation |

The result also affects fatigue. A demanding performance can earn more money while leaving less Alar for later actions.

### 9.4 Repertoire progression

Repertoire is represented by original compositions and motifs, not copied songs. Each piece has:

- difficulty;
- mood;
- venue fit;
- audience tags;
- stamina cost;
- unlock condition.

The vertical slice needs only two pieces: one tutorial piece and one climactic performance arrangement.

### 9.5 Controls and accessibility

- keyboard input with remappable keys;
- controller support;
- timing window adjustment;
- hold-to-confirm option;
- reduced chart density mode;
- practice mode with no economic consequences;
- visual and audio timing cues.

---

## 10. Sygaldry and Artificing

### 10.1 Purpose

Artificing is the tangible, methodical counterpart to Sympathy. The player turns knowledge into objects that solve future problems.

### 10.2 Crafting flow

1. Acquire a base item and materials.
2. Select a known rune pattern.
3. Place runes on a grid.
4. Check polarity, adjacency, direction, and material compatibility.
5. Commit the engraving.
6. Test, sell, equip, or install the finished item.

### 10.3 Rune puzzle rules

Each rune has:

- input/output polarity;
- orientation;
- material requirement;
- energy cost;
- adjacency rules;
- stability value.

The item succeeds when the rune graph connects all required inputs and outputs without an illegal conflict. Later recipes can introduce bridges, insulators, and decoys, but the first crafting puzzle should teach only polarity and adjacency.

### 10.4 Example items

- Sympathy lamp;
- heat-saving charm;
- lock aid;
- workshop tool;
- travel light;
- protective binding;
- Bloodless-like defensive item, subject to fan-project rights and naming review.

### 10.5 Failure states

Crafting failure consumes some materials but should not destroy rare story-critical resources without warning. Failure can produce a flawed item with reduced durability, lower efficiency, or an unexpected side effect.

---

## 11. Naming

Naming is intentionally not a normal skill tree or repeatable spell system. It is a late-game, narrative-facing power that operates outside ordinary Sympathy rules.

### Design rules

- Naming appears only in authored moments of extreme need or insight.
- The player is not asked to type arbitrary words into a parser.
- The experience may use recognition, environmental observation, memory fragments, or a short timing choice.
- Naming scenes bypass ordinary combat and crafting interfaces.
- The outcome should feel consequential and uncanny, not like a stronger version of Sympathy.

Naming is best treated as a special narrative state in the technical architecture, with custom triggers and bespoke presentation.

---

## 12. Survival, Stealth, and Tarbean

### 12.1 Survival resources

Tarbean uses three primary meters:

- **Hunger:** affects movement recovery, dialogue composure, and endurance.
- **Warmth:** decreases in cold areas and during night exposure; low warmth causes health loss.
- **Suspicion:** tracks how much attention guards, gangs, or hostile NPCs are paying to the player.

Health is a consequence meter, not the main survival puzzle. Hunger and warmth should be visible and predictable.

### 12.2 Stealth model

Stealth is based on:

- line of sight;
- light level;
- movement speed;
- noise;
- disguise or social context;
- available cover;
- current suspicion.

Detection proceeds through three states:

1. unnoticed;
2. suspected;
3. discovered.

Suspicion can cool if the player breaks line of sight, changes route, or reaches a safe location. Discovery should usually create a new problem rather than an immediate game over.

### 12.3 Begging and social reading

Begging is a choice-based interaction system. The player assesses an NPC’s mood, wealth signals, hurry, and likely sympathy, then chooses an approach. Success depends on observation, reputation, and prior actions more than random chance.

### 12.4 Safe locations

Safe locations serve as:

- recovery points;
- stash points;
- narrative anchors;
- fast-travel unlocks;
- places to receive rumors and relationship updates.

The player should gradually build a mental map of Tarbean through safe routes and recurring landmarks.

---

## 13. Economy and Life Sim

### 13.1 Economic philosophy

Money is not a score. It is a pressure system that changes what the player can attempt today. Prices and income should be legible, and the player should always have at least one viable way to recover from a poor decision.

### 13.2 Currency and price bands

Use a single primary currency for clarity. Economy values should be tuned in bands rather than individual simulation-heavy prices:

| Band | Example |
|---|---|
| Cheap | Basic food, common materials, small transit cost |
| Moderate | Safe lodging, class supplies, ordinary tools |
| Expensive | Rare materials, quality lodging, special access |
| Critical | Tuition, major debt, rare equipment |

The UI must show the current price, the player’s balance, and the likely consequences of spending before confirmation.

### 13.3 Tuition

Every semester ends with an admissions/interview sequence. The player’s performance modifies tuition.

Inputs include:

- academic progress;
- reputation with faculty;
- dialogue attitude;
- prior conduct;
- demonstrated skills;
- unpaid debts or favors.

The player is never required to hit one exact hidden number. If funds are insufficient, the game opens consequence routes such as borrowing, extra work, delayed access, or a difficult favor.

### 13.4 Income sources

- Fishery crafting and sales;
- Eolian performances after passing the talent-pipe test;
- temporary work and errands;
- selling gathered materials;
- favors and patronage;
- loans from Devi.

Each income source should compete with study time. The optimal play is not to do everything; it is to choose a sustainable rhythm.

### 13.5 Devi’s loans

Loans are fast, useful, and dangerous. A loan record contains:

- principal;
- interest;
- due date;
- collateral or favor;
- consequence tier for missed payment.

The UI shows total repayment, not only the initial amount. Missed payment consequences escalate from reminders to blocked access, social pressure, and high-risk tasks.

### 13.6 Alar as mental stamina

Alar is the player’s mental reserve. It represents concentration and control rather than a generic action-point pool.

Alar is spent by:

- complex Sympathy;
- advanced crafting;
- long Archive sessions;
- intense performances;
- resisting panic or pressure;
- certain dialogue abilities.

Alar is restored through sleep, quiet study, food, safe social connection, and select items. Low Alar increases risk and reduces recovery quality. The game should communicate this as exhaustion and cognitive strain, not as an arbitrary blue bar.

Suggested baseline:

```text
max_alar = 100 + composure_bonus + equipment_bonus
safe_zone = 40–100
strained_zone = 20–39
critical_zone = 0–19
```

The exact numbers are tuning values, not design promises.

---

## 14. University Progression

### 14.1 Classes

Classes are short interactive scenes or focused challenges, not passive cutscenes. Each class grants one of:

- skill experience;
- knowledge tags;
- access to a recipe or working;
- faculty reputation;
- a relationship opportunity;
- a clue.

Primary tracks:

- Sympathy;
- Sygaldry/artificing;
- Medica;
- rhetoric and social reading;
- music;
- Archives/lore;
- Naming awareness.

### 14.2 Study actions

Study actions have three choices:

- safe study: low progress, low Alar cost;
- focused study: strong progress, moderate Alar cost;
- obsessive study: maximum progress, high Alar cost and possible next-day penalties.

### 14.3 Archives

The Archives is a restricted information space with its own risk loop. Access depends on time, reputation, permissions, and concealment. The player searches by topic and location, then chooses how long to remain.

Longer sessions produce better clues but increase:

- Alar drain;
- suspicion;
- chance of interruption;
- opportunity cost elsewhere.

### 14.4 Fishery

The Fishery is the main workbench and crafting hub. Work orders provide predictable income but use time and materials. The Fishery also teaches that good design is constrained by stock, tools, safety, and customer demand.

### 14.5 Eolian

The Eolian is both performance venue and social gate. The player must demonstrate competence before earning talent pipes. Once admitted, the venue becomes a repeatable but limited income source with reputation and fatigue consequences.

### 14.6 Underthing

The Underthing is an exploration layer with nonlinear routes, environmental storytelling, and lower-pressure discovery. It should reward curiosity with:

- unusual materials;
- hidden spaces;
- relationship moments;
- clues;
- Naming foreshadowing.

It should not become an endless procedural dungeon.

---

## 15. Time, Schedules, and World Reactivity

### 15.1 NPC schedule model

NPCs use authored schedule blocks:

```text
schedule_entry = {
  day_pattern,
  time_block,
  location,
  activity,
  prerequisites,
  fallback_location
}
```

Schedules can be authored as reusable templates. If the player arrives after an NPC has left, the game should provide a readable lead rather than a dead end.

### 15.2 State changes

World state can change through:

- day and semester progression;
- completed story beats;
- reputation thresholds;
- purchased or crafted access;
- missed appointments;
- loan status;
- player discoveries.

State changes should be stored as named flags and tags, not scattered boolean checks across scene scripts.

### 15.3 Fast travel

Fast travel unlocks from known routes and safe points. It consumes time and sometimes money. New areas should be traversable on foot at least once so the player understands their relationship in the world.

---

## 16. Quest and Content Design

### 16.1 Quest structure

Quests are authored as compact chains with:

- premise;
- participant list;
- required knowledge;
- available approaches;
- resource costs;
- visible and hidden consequences;
- completion state;
- failure or delay state;
- follow-up hooks.

### 16.2 Quest categories

- main story;
- character relationship;
- skill lesson;
- work order;
- investigation;
- exploration discovery;
- performance opportunity;
- survival opportunity.

### 16.3 Three-route minimum

For important quests, design at least three solution routes where production allows:

1. knowledge/skill route;
2. social/reputation route;
3. resource/risk route.

The vertical slice does not need full branching, but it should demonstrate that the same problem can be approached through more than one player verb.

### 16.4 Investigation board

The journal includes a clue board that stores:

- discovered facts;
- unresolved questions;
- character associations;
- location references;
- confidence level.

The board does not automatically solve mysteries. It helps the player remember what Kvothe has learned and why a lead matters.

---

## 17. Art Direction

### 17.1 Visual target

32-bit-inspired pixel art with detailed environments, readable silhouettes, expressive portraits, and dynamic lighting. The art should feel tactile and slightly grounded rather than glossy or hyper-saturated.

### 17.2 Palette by act

| Act | Palette direction | Lighting behavior |
|---|---|---|
| I | Warm greens, amber firelight, dusk blues | Sympathy can dim or redirect light |
| II | Cold grays, dirty snow, weak orange pockets | Warmth is scarce and visually meaningful |
| III | Academic stone, brass, teal night, Imre color | Artificial light and magic create contrast |

### 17.3 Dynamic Sympathy lighting

The first showcase interaction is pulling light or heat from a campfire. When energy is removed:

- the source dims;
- nearby pixels shift toward cooler values;
- the target brightens or changes state;
- the player receives clear audio feedback;
- excessive transfer produces heat, flicker, or slippage effects.

The effect should be materially visible without requiring expensive real-time lighting. Use a small number of layered light masks, palette swaps, and animated overlays.

### 17.4 Asset standards

- Define a single base tile size and stick to it.
- Use Aseprite for character sheets, environment props, and animation exports.
- Use LDtk for authored maps and collision/intention layers.
- Maintain separate foreground, gameplay collision, lighting, and decoration layers.
- Prefer reusable modular props over unique one-off assets.
- Create silhouette and color readability tests before detail passes.

### 17.5 Animation priorities

Priority order for the solo project:

1. eight-direction movement;
2. idle and interaction poses;
3. lute performance body language;
4. Sympathy casting and slippage;
5. stealth states;
6. story-specific moments;
7. secondary NPC polish.

---

## 18. Audio Direction

Audio should create intimacy and scarcity. Favor original, motif-driven music and diegetic sound over a large soundtrack.

### Audio layers

- caravan ambience;
- campfire, road, forest, and weather beds;
- lute performance audio;
- subtle Sympathy hums and source strain;
- Tarbean wind, footsteps, distant voices, and guarded silence;
- Fishery tools, metal, glass, and workshop resonance;
- Archives paper, wood, and quiet movement;
- relationship motifs and act transition themes.

All music and samples must be original or properly licensed. The project should use temporary audio placeholders during prototyping and replace them before any public build.

---

## 19. UI/UX

### 19.1 HUD

The HUD should remain quiet during exploration. Show only:

- current time block;
- Alar;
- health when relevant;
- active hunger/warmth/suspicion in Act II;
- currency when near an economic decision;
- contextual interaction prompt.

### 19.2 Menus

- journal and clue board;
- inventory;
- skills and known workings;
- relationships and reputation;
- map and discovered routes;
- settings and accessibility.

### 19.3 Feedback principles

Every important action should answer:

- what did I do?
- what did it cost?
- what changed?
- what can I try next?

Avoid unexplained failure messages such as “You cannot do that.” Prefer “The link is too weak; use a similar material or lower the effect.”

### 19.4 Accessibility

Required baseline options:

- remappable controls;
- keyboard-only and controller play;
- scalable text;
- high-contrast interaction highlights;
- colorblind-safe state indicators;
- reduced screen shake and flashing;
- rhythm timing assistance;
- pause during non-cinematic minigames;
- subtitle size and background controls;
- audio mixing sliders;
- reduced survival pressure mode for testing or accessibility.

---

## 20. Technical Architecture

### 20.1 Recommended stack

- Godot 4.x;
- GDScript for gameplay and tools;
- LDtk for authored level design;
- Aseprite for pixel art and animation;
- Git for version control;
- OpenCode CLI for AI-assisted code generation, refactoring, test generation, and documentation support.

Unity remains viable if existing expertise or asset investment makes it materially faster, but choosing both engines is out of scope. Commit to one engine before production begins; this GDD assumes Godot.

### 20.2 Core architecture

Use data-driven resources and small, explicit managers:

```text
GameRoot
├── SaveManager
├── TimeManager
├── EconomyManager
├── RelationshipManager
├── QuestManager
├── InventoryManager
├── SkillManager
├── DialogueRunner
├── MinigameHost
└── SceneRouter
```

Systems should communicate through signals/events or narrow service interfaces. Scene scripts should orchestrate local presentation, not own global game state.

### 20.3 Suggested project structure

```text
project/
├── scenes/
│   ├── core/
│   ├── player/
│   ├── npcs/
│   ├── ui/
│   ├── minigames/
│   └── locations/
├── scripts/
│   ├── systems/
│   ├── dialogue/
│   ├── quests/
│   ├── minigames/
│   └── tools/
├── data/
│   ├── characters/
│   ├── items/
│   ├── recipes/
│   ├── workings/
│   ├── schedules/
│   └── dialogue/
├── art/
├── audio/
├── maps/
├── tests/
└── docs/
```

### 20.4 Save data

Save data should store versioned state:

- current act, day, and time block;
- player stats and skills;
- inventory and currency;
- relationship values;
- reputation values;
- quest states;
- discovered clues;
- unlocked locations;
- loans and due dates;
- world flags;
- settings and accessibility preferences.

Save migrations are required whenever a serialized field changes. Test saves should include a debug export/import path.

### 20.5 AI-assisted development rules

AI may assist with:

- boilerplate and small isolated scripts;
- test cases;
- data conversion and validation tools;
- dialogue formatting;
- content variant generation for human review;
- refactoring proposals;
- documentation and changelog drafts.

The human owner remains responsible for:

- canon choices;
- final narrative voice;
- rights and asset provenance;
- architecture approval;
- balancing decisions;
- every public build.

Every AI-generated code change must be small enough to review, tested in isolation, and committed with a clear message.

---

## 21. Content Pipeline

### 21.1 Map pipeline

1. Block out rooms and traversal in LDtk.
2. Add collision and interaction layers.
3. Add navigation markers and schedule points.
4. Test with placeholder art.
5. Export/import into Godot.
6. Add lighting and set dressing.
7. Run traversal, interaction, and performance checks.

### 21.2 Sprite pipeline

1. Define silhouette and palette.
2. Create idle and movement frames.
3. Export sprite sheets from Aseprite.
4. Validate scale, pivot, collision footprint, and palette.
5. Integrate into a reusable character scene.

### 21.3 Dialogue pipeline

Dialogue should be stored as structured data with IDs, speaker, text, choices, conditions, effects, and localization-ready metadata. Do not bury major branching logic inside long scene scripts.

### 21.4 Naming conventions

Use stable IDs:

```text
char_abenthy
item_lamp_sympathy_01
work_light_transfer_basic
quest_act1_abenthy_lesson
flag_act1_chandrian_attack_seen
```

Stable IDs matter more than human-readable filenames because they prevent AI-assisted content changes from silently breaking references.

---

## 22. Testing and Quality Bar

### 22.1 Automated tests

Test pure logic for:

- Sympathy energy and risk calculations;
- Alar spending and recovery;
- economy transactions and loans;
- time advancement;
- reputation thresholds;
- quest state transitions;
- schedule resolution;
- inventory capacity;
- save/load and migration;
- rune graph validation.

### 22.2 Content validation

Build editor or CLI checks for:

- missing dialogue references;
- unreachable quest states;
- missing item IDs;
- invalid schedule locations;
- recipes using undefined materials;
- scenes without spawn points;
- broken save-version migrations;
- map layers missing required metadata.

### 22.3 Playtest questions

For every milestone, test:

- Does the player know what they can do?
- Do costs feel visible before commitment?
- Is failure understandable?
- Is there a recovery path?
- Does the system create a meaningful decision?
- Does the story beat still land after repeated play?
- Is the player curious about the next location or clue?

### 22.4 Definition of done

A feature is done when it has:

- a written rule;
- a working implementation;
- a failure state;
- save/load coverage if stateful;
- at least one test or validation check;
- placeholder or final feedback;
- a short manual playtest pass;
- no known blocker in the vertical-slice path.

---

## 23. Production Roadmap

### Phase 0: Foundation

**Goal:** Establish the project spine before content production.

Deliverables:

- Godot project and repository;
- input map;
- player movement;
- camera and scene transition;
- save/load shell;
- data ID conventions;
- LDtk import test;
- Aseprite export test;
- basic dialogue runner;
- debug overlay for time, Alar, money, flags, and scene ID.

Exit criteria: a placeholder character can move between two scenes, talk to a test NPC, save, load, and retain state.

### Phase 1: Edema Ruh vertical slice

**Goal:** Prove the game’s emotional and mechanical thesis in a 45–90 minute slice.

Deliverables:

- one caravan route;
- one forest campsite;
- a small troupe roster;
- Abenthy tutorial dialogue;
- inventory and basic currency;
- two original lute charts;
- Sympathy source/link/target UI;
- light or heat transfer working;
- Alar drain and recovery;
- basic dynamic lighting response;
- one optional exploration thread;
- Chandrian attack sequence;
- autosave and end-of-slice state.

Exit criteria: see the vertical-slice checklist below.

### Phase 2: Modular architecture pass

**Goal:** Ensure the project can expand without rewriting Act I.

Deliverables:

- data-driven quests;
- relationship and reputation managers;
- schedule system;
- reusable minigame host;
- content validation scripts;
- save migration versioning;
- documented scene and data templates.

Exit criteria: a second authored location can be added with data and scenes rather than global-system rewrites.

### Phase 3: Tarbean prototype

**Goal:** Prove the genre shift and survival loop.

Deliverables:

- one slum district;
- warmth and hunger;
- suspicion and guard AI;
- stealth routes;
- begging interactions;
- safe shelter;
- one pageant sequence;
- trauma-phase music/Sympathy lockout.

Exit criteria: a player can survive a complete Tarbean day, recover from failure, and reach the pageant through more than one route.

### Phase 4: University and Imre core

**Goal:** Build the main life-sim hub.

Deliverables:

- four-block day and semester progression;
- classes;
- tuition and admissions;
- Fishery workbench;
- Sygaldry grid crafting;
- Eolian performance and talent pipes;
- Archives access;
- Underthing prototype;
- NPC schedules;
- loans and debt;
- relationship/reputation consequences.

Exit criteria: the player can complete a representative University week while making a meaningful choice between study, work, performance, and investigation.

### Phase 5: Full narrative and polish

**Goal:** Complete the selected adaptation scope and prepare a stable public build.

Deliverables:

- complete authored content within the chosen scope;
- Trebon/Draccus sequence;
- patron thread;
- Naming set pieces;
- final art and audio pass;
- accessibility pass;
- balance pass;
- rights and asset provenance review;
- release build and documentation.

---

## 24. Act I Vertical-Slice Acceptance Checklist

The slice is successful when all of the following are true:

### Player and world

- Player movement feels responsive in all intended directions.
- The player can enter and leave the caravan camp without broken collision.
- At least three NPCs have distinct schedules or interaction states.
- The player can inspect environmental objects and receive useful context.

### Dialogue and narrative

- Abenthy teaches through an interactive conversation, not only exposition.
- At least one dialogue choice changes a relationship or later line.
- The troupe feels like a community before the attack.
- The Chandrian attack is authored, legible, and emotionally paced.

### Music

- The player can practice without economic consequences.
- A performance has visible timing feedback and audible response.
- Performance quality changes reward or reaction.
- The chart supports keyboard and controller input.

### Sympathy

- The player selects a source, link, target, and effect.
- The UI shows cost and risk before commitment.
- A successful working visibly changes the environment.
- A failed or risky working produces understandable consequences.
- Alar is spent and recoverable.

### Technical quality

- The slice can be completed from a clean save.
- Save/load preserves story flags, inventory, and Alar.
- No critical path requires a debug command.
- A single test build can be exported and played outside the editor.
- Placeholder assets are labeled and have a replacement plan.

### Emotional quality

- The player understands why the caravan matters.
- The player feels curiosity about Sympathy.
- The attack changes the meaning of the earlier systems.
- The ending creates forward momentum without pretending to resolve the whole story.

---

## 25. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Scope grows to a full commercial RPG | Project stalls | Treat Act I as the only committed milestone; maintain cut list |
| Canon and rights uncertainty | Public release blocked | Use original assets, avoid copied prose/audio, keep project noncommercial |
| AI-generated code becomes inconsistent | Bugs and rewrite cost | Small changes, tests, stable interfaces, human review |
| Simulation becomes busywork | Player fatigue | Four time blocks, visible costs, recovery paths |
| Rhythm system consumes too much production time | Slice delay | Two-chart minimum; use a reusable chart format |
| Dynamic lighting is expensive | Visual polish slips | Use palette/overlay techniques before real-time lighting |
| Content volume overwhelms one creator | Incomplete acts | Reuse systems, compact locations, authored vignettes, no procedural sprawl |
| Narrative branches multiply | QA burden | Branch tone, costs, and relationships; preserve authored major beats |
| Book-three mysteries are overcommitted | Canon contradiction | End at the selected early-life scope and preserve ambiguity |
| Unclear failure states frustrate players | Drop-off | Show costs, risk, consequences, and recovery options |

---

## 26. Cut List and Stretch Goals

### Cut first if schedule slips

1. Full combat system.
2. Large voice-over ambitions.
3. Procedural map generation.
4. Broad NPC daily simulation.
5. Multiple difficulty modes.
6. Large optional quest count.
7. Complex instrument customization.
8. Fully reactive weather across every location.

### Stretch goals

- New Game Plus with altered knowledge flags;
- optional challenge mode for Sympathy risk;
- expanded lute repertoire;
- more Underthing routes;
- additional patron outcomes;
- developer commentary mode;
- mod-friendly data definitions.

Stretch goals begin only after the main narrative path is stable and tested.

---

## 27. Immediate Next Actions

1. Commit to Godot 4 as the engine.
2. Create the project repository and stable folder structure.
3. Build the player movement and scene transition shell.
4. Import one LDtk test map.
5. Create one reusable NPC scene and dialogue data file.
6. Implement the debug overlay and save/load shell.
7. Prototype the Sympathy UI with placeholder art.
8. Prototype one eight-bar lute chart with placeholder audio.
9. Block out the caravan camp and forest route.
10. Playtest the first five minutes before adding content.

The project should not begin with final art, full narrative scripting, or a large map. The first proof is a small, playable loop in which movement, conversation, music, and one Sympathy working already feel like the same game.

