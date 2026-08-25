# AGENTS.md — Audio Pipeline

Rules for any agent working on or through `tools/audio-pipeline/`. These are
hard constraints, not suggestions. See `README.md` for how to run things.

## Licensing (never violate)

- **Prefer CC0 / public domain.** Use it whenever a suitable option exists.
- **CC-BY is permitted** only with identifiable author, source URL, and clean
  terms — record the attribution in `metadata/licenses.json`.
- **Reject CC-BY-NC**, non-commercial-only, no-derivatives,
  "personal use only", unclear, and unknown licenses. If the license cannot
  be established from the actual asset page, mark `LICENSE UNKNOWN` and reject.
- **Never infer a license** from "free", "royalty free", page titles, search
  snippets, filenames, or uploader descriptions alone.
- **Never use ripped audio**: game rips, movie/TV audio, audiobook or
  soundtrack recordings, YouTube/Spotify rips, copyrighted fan arrangements.
  This includes anything marketed as an "official Name of the Wind soundtrack"
  or fan songs based on copyrighted melodies.
- CC-BY-SA, OGA-BY, GPL-linked audio and custom site licenses go to
  `candidates/review-required/` — never auto-publish them.

## Workflow (always in this order)

```
requirement -> search -> license validation -> candidate -> download ->
preserve source + license evidence -> process -> metadata -> review ->
publish -> credits
```

1. Never put downloads directly into production. Originals go to
   `sources/original/`, processed files to `processed/`, and only files
   published by `publish-audio.mjs` belong under `audio/`.
2. Preserve every original file. Processing must be non-destructive.
3. Record source site, creator, title, URL, download date, and license for
   every asset in `metadata/licenses.json` plus a per-asset evidence file in
   `sources/licenses/<id>.json`.
4. Search approved sources first (OpenGameArt CC0 → Freesound CC0 → Pixabay →
   OpenGameArt/Freesound CC-BY). Search by mood/environment/instrument/gameplay
   purpose ("medieval fantasy tavern lute CC0"), never by IP name.
5. Music is always published as `review.status: pending` and stays out of the
   shipped soundtrack until a human approves it. Signature SFX (sympathy,
   Naming, Chandrian, lute performances, major UI) also require approval.

## Asset conventions

- Game code references **logical IDs** (`SFX_PAGE_TURN`, `MUS_UNIVERSITY_DAY`,
  `AMB_TARBEAN_NIGHT`) via `audio/audio-manifest.json` — never hardcode file
  paths in gameplay scripts.
- Ship logical filenames: `sword_swing_light_01.ogg`, not
  `freesound_839492.wav` or `medieval_music_final.mp3`.
- Keep **variants** for repeated sounds (footsteps 4–8, sword swings 3–6,
  page turns 3–5...); vary pick order, never pitch-shift wildly.
- Ambience loops should be genuinely loopable (30–180 s, no clicks or obvious
  repeating events at boundaries).
- Normalize loudness within categories (music/ambience/combat/movement/ui/
  magic), preserve dynamics, avoid clipping, trim only accidental silence.
- Keep source audio (`tools/audio-pipeline/sources/original/`) strictly
  separate from production audio (`audio/`).

## Hygiene

- Update `CREDITS/AUDIO-CREDITS.*` (via `npm run audio:credits`) whenever
  assets change; CC0 assets stay listed for provenance.
- Run `npm test` after touching pipeline scripts.
- After adding/renaming files under `audio/`, run the Godot import step before
  headless suites:
  `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path "<project>" --import`
