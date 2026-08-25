# AGENTS.md — lpc-factory working notes

## Environment facts (verified)

- Node pipeline only: `pngjs` does all compositing/recoloring. Aseprite CLI
  exists on this machine but its headless scripting is unreliable here:
  `Image(path)` silently returns 1x1, `--script-param` is not delivered,
  and standalone `Image{fromFile}` drops indexed-color palettes. Do not
  reintroduce Aseprite Lua for composition.
- Upstream per-animation PNGs use NATURAL frame counts, not padded strips:
  idle = 2f x4d (128x256), walk = 9f x4d (576x256), hurt = 6f x1d (384x64),
  weapons slash_128 = 6f x4d @128px. Canvas size derives from the widest
  layer; never assume 13 columns outside `meta.animations`.
- Body PNGs are indexed-color pngjs expands to RGBA transparently.

## Conventions

- Always run pipeline steps from `tools/lpc-factory/` so relative paths in
  manifests stay stable.
- After changing upstream pin or sheet definitions:
  `node scripts/inspect-lpc.mjs` must be rerun before any build.
- New characters/weapons go through a smoke build before commit;
  the build fails hard if a composed sheet has 0 opaque pixels.
- Keep custom NOTW ramps as 6-shade arrays matching LPC index order.
- Never edit anything under `upstream/universal-lpc/` (gitignored clone).

## Known quirks

- `weapon.arming_sword` availability index says combat_idle unsupported but
  files resolve fine via variant-dir fallback — warning is benign.
- Attack-strip layers (`attack_slash/{fg,bg}/<variant>.png`) have no
  animation subfolder; resolver fallback C covers this layout.
