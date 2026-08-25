AUDIO SEARCH
============
Requirement group: plan s44 first-pass vertical slice (weapons/coins/cloth/door)
Date: 2026-08-24
Searcher: pipeline session (agent)

Search terms used
-----------------
"RPG sword swing unsheathe CC0 opengameart", "coin pickup CC0",
"cloth foley CC0", "wooden door open CC0"

Candidate 1
-----------
Source: OpenGameArt — "RPG Sound Pack" by artisticdude
URL: https://opengameart.org/content/rpg-sound-pack
License: CC0 (verified on the asset page itself)
Format: WAV (lossless originals) inside rpg_sound_pack.zip, 12.5 MB
Assessment: GOOD
Notes: 3 sword swings + 5 unsheathes + 3 coins + cloth/heavy cloth +
       chainmail x2 + wooden door. Covers several s44 slice events at once.

Candidate 2
-----------
Source: Freesound (footsteps/page turns candidates)
License: mixed per sound; downloads require an account/OAuth API key
Assessment: DEFERRED
Reason: no programmatic download path available in this environment;
        manual acquisition session required for Freesound material.

Candidate 3
-----------
Source: Pixabay sound effects
License: Pixabay Content License (per-asset page record required)
Assessment: DEFERRED
Reason: API-key gated; to be handled in a dedicated acquisition pass with
        per-asset page evidence capture.

Disposition
-----------
APPROVED and ingested as asset `oga_rpg_sound_pack`:
  SFX_SWORD_SWING_LIGHT  <- battle/swing.wav, swing2.wav, swing3.wav   (3 variants)
  SFX_SWORD_DRAW         <- battle/sword-unsheathe{,2,3,4,5}.wav        (5 variants)
  SFX_COIN_SINGLE        <- inventory/coin{,2,3}.wav                    (3 variants)
  SFX_CLOTH_MOVE_LIGHT   <- inventory/cloth.wav                         (1 variant)
  SFX_CLOTH_MOVE_HEAVY   <- inventory/cloth-heavy.wav                   (1 variant)
  SFX_GEAR_RATTLE        <- inventory/chainmail1.wav, chainmail2.wav    (2 variants)
  SFX_DOOR_WOOD_OPEN     <- world/door.wav                              (1 variant)

Deliberately NOT mapped from this pack (signature sounds need human review,
plan s41): spell.wav / magic1.wav (sympathy family), NPC shade*.wav
(Chandrian family — must not sound like monsters), interface1-6.wav
(Kenney UI set already covers these events).

Still unfilled after this pass: sword sheathe/hit/block/parry variants,
footsteps (all surfaces), page turns/books, doors close/heavy, most UI,
all ambience beyond the two synth loops, all music (review-gated).
