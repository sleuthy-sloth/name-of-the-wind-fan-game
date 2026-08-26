// npc-generator.mjs — Deterministic pool-based NPC character generation.
// An archetype definition looks like:
//
//   name: ruh_crew
//   count: 6
//   seed: 20260825          # any string or int; drives all picks
//   bodyTypes: [male, female]   # cycled deterministically
//   animations: [idle, walk]
//   slots:                   # ordered; one layer per slot per NPC
//     - slotName: hair       # optional label
//       pool:
//         - item: hair.page
//           colors: [black, brown]   # optional; picked when item supports recolor
//         - item: hair.balding
//           variants: [none]          # optional variant pool
//     - pool:
//         - item: clothes.longsleeve
//           colors: [ruh_green, university_blue]   # colors may name custom palettes
//
// Output is a list of normalized character defs. Generation is fully
// deterministic for a given (seed, count, archetype content): the same
// archetype always yields byte-identical definitions.

import fs from "fs";
import path from "path";
import yaml from "js-yaml";

// FNV-1a string hash -> uint32 seed material
export function hashString(str) {
  let h = 0x811c9dc5;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

// mulberry32 PRNG — small, fast, good enough for deterministic art picks
export function mulberry32(seed) {
  let a = seed >>> 0;
  return function next() {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function pickFrom(rand, list) {
  return list[Math.floor(rand() * list.length) % list.length];
}

export function validateArchetype(archetype, assetIndex) {
  const errors = [];
  if (!archetype.name) errors.push("Missing required field: name");
  const count = Number(archetype.count);
  if (!Number.isInteger(count) || count < 1) {
    errors.push("Field 'count' must be a positive integer");
  }
  if (!archetype.slots || !Array.isArray(archetype.slots) || archetype.slots.length === 0) {
    errors.push("Missing 'slots' array");
    return { valid: false, errors };
  }
  const catalog = assetIndex.catalog;
  archetype.slots.forEach((slot, si) => {
    const label = "slots[" + si + "]" + (slot && slot.slotName ? "(" + slot.slotName + ")" : "");
    if (!slot || !Array.isArray(slot.pool) || slot.pool.length === 0) {
      errors.push(label + ": missing non-empty 'pool' array");
      return;
    }
    slot.pool.forEach((entry, pi) => {
      const elabel = label + ".pool[" + pi + "]";
      if (!entry || !entry.item) {
        errors.push(elabel + ": missing 'item'");
        return;
      }
      if (!catalog[entry.item]) {
        errors.push(elabel + ": catalog item not found: " + entry.item);
      }
    });
  });
  return { valid: errors.length === 0, errors };
}

export function generateNpcs(archetype, assetIndex, overrides = {}) {
  const validation = validateArchetype(archetype, assetIndex);
  if (!validation.valid) {
    throw new Error("invalid archetype:\n  - " + validation.errors.join("\n  - "));
  }

  const name = archetype.name;
  const count = overrides.count || Number(archetype.count);
  const baseSeedStr = String(overrides.seed !== undefined ? overrides.seed : archetype.seed !== undefined ? archetype.seed : name);
  const bodyTypes = (overrides.bodyTypes || archetype.bodyTypes ||
    ["male", "female"]).filter(bt => bt !== "any" && bt !== "*");
  const animations = archetype.animations || ["idle", "walk"];

  const npcs = [];
  for (let i = 0; i < count; i++) {
    const rand = mulberry32(hashString(baseSeedStr + "::npc:" + i));
    const bodyType = pickFrom(rand, bodyTypes.length ? bodyTypes : ["male"]);
    const layers = [];

    for (const slot of archetype.slots) {
      // Per-slot bodyType gating (e.g. beards only on male bodies)
      if (Array.isArray(slot.bodyTypes) && !slot.bodyTypes.includes(bodyType)) {
        continue;
      }
      // Pick the pool entry first, then its color/variant — order matters
      // for determinism and must be stable across runs.
      const entry = pickFrom(rand, slot.pool);
      // Optional slots can resolve to "no layer" without breaking determinism:
      // the skip decision consumes no randomness.
      if (slot.optional && rand() < 0.5) continue;
      const catalogItem = assetIndex.catalog[entry.item] || {};
      const supportsRecolor = Boolean(catalogItem.recolors && catalogItem.recolors.material);
      const layer = { item: entry.item };

      if (Array.isArray(entry.variants) && entry.variants.length > 0 &&
          !(entry.variants.length === 1 && entry.variants[0] === "none")) {
        layer.variant = pickFrom(rand, entry.variants);
      } else if (Array.isArray(entry.variants) && entry.variants[0] === "none") {
        layer.variant = null;
      }

      if (supportsRecolor) {
        // Recolor-capable item: colors drive palette remapping.
        if (Array.isArray(entry.colors) && entry.colors.length > 0) {
          layer.color = pickFrom(rand, entry.colors);
        }
      } else if (!layer.variant &&
                 Array.isArray(entry.colors) && entry.colors.length > 0 &&
                 Array.isArray(catalogItem.variants) && catalogItem.variants.length > 0) {
        // Variant-dir item (e.g. clothes.tunic): treat color names as variants.
        const valid = entry.colors.filter(c => catalogItem.variants.includes(c));
        if (valid.length > 0) {
          layer.variant = pickFrom(rand, valid);
        }
      }

      if (entry.palette) layer.palette = entry.palette;
      layers.push(layer);
    }

    npcs.push({
      name: name + "_" + String(i).padStart(2, "0"),
      bodyType,
      animations: [...animations],
      layers,
    });
  }

  return npcs;
}

export function writeNpcDefs(npcs, outDir) {
  fs.mkdirSync(outDir, { recursive: true });
  const written = [];
  for (const def of npcs) {
    const filePath = path.join(outDir, def.name + ".yaml");
    const doc = {
      name: def.name,
      bodyType: def.bodyType,
      animations: def.animations,
      layers: def.layers.map(l => {
        const out = { item: l.item };
        if (l.color) out.color = l.color;
        if (l.variant) out.variant = l.variant;
        if (l.palette) out.palette = l.palette;
        return out;
      }),
    };
    fs.writeFileSync(filePath, yaml.dump(doc, { lineWidth: 100 }), "utf8");
    written.push(filePath);
  }
  return written;
}
