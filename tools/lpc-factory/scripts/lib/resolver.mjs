// resolver.mjs — Resolve asset paths from the catalog index.
// Handles three upstream layouts:
//   flat        : basePath/<animation>.png            (body/hair/clothes)
//   full-sheet  : pick <animation>.png from files list (some hair sets)
//   variant-dir : basePath/<animation>/<variant>.png   (weapons universal)
//                 or basePath/<variant>.png            (weapons attack strips)

import fs from "fs";
import path from "path";
import { resolveAnimName, getFrameSize } from "./lpc-source.mjs";

function mkResult(layerKey, zPos, file, frameSize, type) {
  return { layerKey, zPos, file, frameSize, type };
}

export function resolveLayerFile(item, layerKey, bodyType, animation, upstreamRoot, variant) {
  const layer = item.layers[layerKey];
  if (!layer) return null;
  const bodyPath = layer.paths[bodyType];
  if (!bodyPath) return null;

  // Layer tied to a different custom animation than requested -> skip
  if (layer.customAnimation && layer.customAnimation !== animation) return null;

  const basePath = path.join(upstreamRoot, "spritesheets", bodyPath);
  const animName = resolveAnimName(animation);
  const frameSize = getFrameSize(animation);

  const avail = item.availability?.[bodyType]?.[animation];
  if (avail && avail.exists) {
    if (avail.type === "flat") {
      const f = path.join(basePath, avail.file);
      if (fs.existsSync(f)) return mkResult(layerKey, layer.zPos, f, frameSize, "flat");
    } else if (avail.type === "full-sheet" && avail.files) {
      const match = avail.files.find(f => {
        const b = f.replace(/\.png$/, "").toLowerCase();
        return b === animName.toLowerCase() || b === animation.toLowerCase();
      });
      if (match) {
        const f = path.join(basePath, match);
        if (fs.existsSync(f)) return mkResult(layerKey, layer.zPos, f, frameSize, "full-sheet");
      }
    } else if (avail.type === "variant-dir" && avail.files) {
      const vName = variant || avail.files[0].replace(/\.png$/, "");
      const f1 = path.join(basePath, animName, vName + ".png");
      if (fs.existsSync(f1)) return mkResult(layerKey, layer.zPos, f1, frameSize, "variant-dir");
      const f2 = path.join(basePath, vName + ".png");
      if (fs.existsSync(f2)) return mkResult(layerKey, layer.zPos, f2, frameSize, "variant-dir");
    }
  }

  // Fallback A: flat basePath/<animation>.png
  const direct = path.join(basePath, animName + ".png");
  if (fs.existsSync(direct)) return mkResult(layerKey, layer.zPos, direct, frameSize, "flat");

  if (variant) {
    // Fallback B: basePath/<animation>/<variant>.png
    const vAnim = path.join(basePath, animName, variant + ".png");
    if (fs.existsSync(vAnim)) return mkResult(layerKey, layer.zPos, vAnim, frameSize, "variant-dir");
    // Fallback C: basePath/<variant>.png (attack strips: files sit directly
    // in the layer directory, no animation subfolder)
    const vDirect = path.join(basePath, variant + ".png");
    if (fs.existsSync(vDirect)) return mkResult(layerKey, layer.zPos, vDirect, frameSize, "variant-direct");
  } else {
    // No variant: default first *.png directly in dir (sorted for determinism)
    try {
      const entries = fs.readdirSync(basePath).filter(f => f.endsWith(".png")).sort();
      if (entries.length > 0 && fs.statSync(path.join(basePath, entries[0])).isFile()) {
        const f = path.join(basePath, entries[0]);
        return mkResult(layerKey, layer.zPos, f, frameSize, "variant-default");
      }
    } catch (e) { /* dir unreadable */ }
  }

  return null;
}

export function resolveItemLayers(item, bodyType, animation, upstreamRoot, variant) {
  const results = [];
  for (const layerKey of Object.keys(item.layers || {})) {
    const r = resolveLayerFile(item, layerKey, bodyType, animation, upstreamRoot, variant);
    if (r) results.push(r);
  }
  results.sort((a, b) => a.zPos - b.zPos);
  return results;
}

export function itemHasAnimation(item, bodyType, animation, upstreamRoot) {
  const avail = item.availability?.[bodyType]?.[animation];
  if (avail) return avail.exists;
  for (const layerKey of Object.keys(item.layers || {})) {
    const r = resolveLayerFile(item, layerKey, bodyType, animation, upstreamRoot, null);
    if (r) return true;
  }
  return false;
}

export function getAvailableAnimations(item, bodyType, upstreamRoot) {
  const avail = item.availability?.[bodyType];
  if (avail) return Object.keys(avail).filter(a => avail[a].exists);
  return (item.animations || []).filter(a => itemHasAnimation(item, bodyType, a, upstreamRoot));
}

export function getAvailableVariants(item, bodyType, animation, upstreamRoot) {
  const avail = item.availability?.[bodyType]?.[animation];
  if (avail && avail.type === "variant-dir" && avail.files) {
    return avail.files.map(f => f.replace(/\.png$/, ""));
  }
  return [];
}
