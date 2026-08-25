// palettes.mjs — Load LPC palette definitions and build recolor maps
// Palette format: { "colorName": ["#shade0", ..., "#shade5"] }
// Recoloring maps each shade of a source color to the corresponding shade
// of a target color (by index, 0=darkest -> 5=lightest).

import fs from "fs";
import path from "path";

export function loadPalette(upstreamRoot, material, name) {
  const candidates = [
    path.join(upstreamRoot, "palette_definitions", material, material + "_" + name + ".json"),
    path.join(upstreamRoot, "palette_definitions", material, name + ".json"),
  ];
  for (const p of candidates) {
    if (fs.existsSync(p)) return JSON.parse(fs.readFileSync(p, "utf8"));
  }
  throw new Error("Palette not found: " + material + "/" + name);
}

export function getColorRamp(palette, colorName) {
  const ramp = palette[colorName];
  if (!ramp) {
    throw new Error("Color \"" + colorName + "\" not found. Available: " + Object.keys(palette).join(", "));
  }
  return ramp;
}

export function buildRecolorMap(sourceRamp, targetRamp) {
  const map = {};
  const len = Math.min(sourceRamp.length, targetRamp.length);
  for (let i = 0; i < len; i++) {
    const src = sourceRamp[i].toLowerCase();
    const tgt = targetRamp[i].toLowerCase();
    if (src !== tgt) map[src] = tgt;
  }
  return map;
}

// Detect which named color in a palette best matches an RGBA pixel buffer.
// Scores each color by how many of its shades appear in the sprite.
export function detectSourceColor(data, palette) {
  // Collect unique opaque hex colors
  const seen = new Set();
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] === 0) continue;
    seen.add("#" +
      data[i].toString(16).padStart(2, "0") +
      data[i + 1].toString(16).padStart(2, "0") +
      data[i + 2].toString(16).padStart(2, "0"));
  }
  let best = null;
  let bestHits = -1;
  for (const [name, ramp] of Object.entries(palette)) {
    let hits = 0;
    for (const shade of ramp) {
      if (seen.has(shade.toLowerCase())) hits++;
    }
    if (hits > bestHits) {
      bestHits = hits;
      best = name;
    }
  }
  return best;
}
