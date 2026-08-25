// composer.mjs — Build composition manifests from character definitions.
// recolorSpec = {
//   material,
//   sourcePaletteFile,  // upstream material palette (native sprite ramps)
//   targetPaletteFile,  // optional factory palette (palettes/notw-*.json)
//   color               // target color name
// }
// The compositor detects which native upstream ramp the pixels use, then
// maps it shade-by-shade onto the target ramp (factory or upstream).

import fs from "fs";
import path from "path";
import { resolveItemLayers } from "./resolver.mjs";
import { getFrameSize, isCustomAnim, CUSTOM_ANIMATIONS, DIRECTIONS } from "./lpc-source.mjs";

function buildRecolorSpec(factoryRoot, upstreamRoot, item, layerDef) {
  if (!item.recolors || !item.recolors.material || !layerDef.color) return null;
  const material = item.recolors.material;
  const first = (item.recolors.palettes && item.recolors.palettes[0]) || "ulpc";

  const sourcePaletteFile = path.join(
    upstreamRoot, "palette_definitions", material, material + "_" + first + ".json"
  );
  if (!fs.existsSync(sourcePaletteFile)) {
    console.warn("  warn: upstream palette missing for material " + material +
      " (" + sourcePaletteFile + "); skipping recolor");
    return null;
  }

  let targetPaletteFile = null;
  if (layerDef.palette) {
    const withMaterial = path.join(factoryRoot, "palettes", layerDef.palette + "-" + material + ".json");
    const plain = path.join(factoryRoot, "palettes", layerDef.palette + ".json");
    if (fs.existsSync(withMaterial)) targetPaletteFile = withMaterial;
    else if (fs.existsSync(plain)) targetPaletteFile = plain;
    else console.warn("  warn: custom palette \"" + layerDef.palette + "\" not found; using upstream target");
  }

  return {
    material,
    sourcePaletteFile,
    targetPaletteFile,
    color: layerDef.color,
  };
}

export function buildManifest(characterDef, assetIndex, upstreamRoot, factoryRoot) {
  const catalog = assetIndex.catalog;
  const manifest = {
    character: characterDef.name,
    bodyType: characterDef.bodyType,
    animations: characterDef.animations || [],
    layers: [],
  };

  for (const anim of manifest.animations) {
    const frameSize = getFrameSize(anim);
    const frames = isCustomAnim(anim) ? CUSTOM_ANIMATIONS[anim].frames : 13;
    const directions = DIRECTIONS.length;

    const animEntry = { animation: anim, frameSize, frames, directions, images: [] };

    for (const layerDef of characterDef.layers) {
      const item = catalog[layerDef.item];
      if (!item) throw new Error("Catalog item not found: " + layerDef.item);

      const resolved = resolveItemLayers(
        item, characterDef.bodyType, anim, upstreamRoot, layerDef.variant
      );
      const recolorSpec = buildRecolorSpec(factoryRoot, upstreamRoot, item, layerDef);

      for (const r of resolved) {
        animEntry.images.push({ zPos: r.zPos, file: r.file, recolorSpec });
      }
    }

    animEntry.images.sort((a, b) => a.zPos - b.zPos);
    manifest.layers.push(animEntry);
  }

  return manifest;
}

export function manifestSummary(manifest) {
  const totalImages = manifest.layers.reduce((s, l) => s + l.images.length, 0);
  const detail = manifest.layers.map(l => l.animation + "(" + l.images.length + ")").join(", ");
  return {
    character: manifest.character,
    bodyType: manifest.bodyType,
    animations: manifest.layers.length,
    totalImages,
    detail,
  };
}
