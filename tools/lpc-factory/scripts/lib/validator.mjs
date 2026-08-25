// validator.mjs — Validate definitions and composition manifests

import { BODY_TYPES, resolveAnimName, isCustomAnim } from "./lpc-source.mjs";
import { itemHasAnimation, getAvailableVariants } from "./resolver.mjs";

// Validate a character definition against the asset index
export function validateCharacterDef(def, assetIndex) {
  const errors = [];
  const warnings = [];

  // Check name
  if (!def.name) {
    errors.push("Missing required field: name");
  }

  // Check bodyType
  if (!def.bodyType) {
    errors.push("Missing required field: bodyType");
  } else if (!BODY_TYPES.includes(def.bodyType)) {
    errors.push(`Invalid bodyType: ${def.bodyType}. Valid: ${BODY_TYPES.join(", ")}`);
  }

  // Check animations
  if (!def.animations || def.animations.length === 0) {
    errors.push("No animations specified");
  }

  // Check layers
  if (!def.layers || def.layers.length === 0) {
    errors.push("No layers specified");
  }

  const catalog = assetIndex.catalog;

  for (const layer of def.layers || []) {
    // Check item exists in catalog
    const item = catalog[layer.item];
    if (!item) {
      errors.push(`Catalog item not found: ${layer.item}`);
      continue;
    }

    // Check bodyType is supported by this item
    const hasBodyType = Object.values(item.layers || {}).some(
      l => l.paths && l.paths[def.bodyType]
    );
    if (!hasBodyType) {
      warnings.push(`Item ${layer.item} does not support bodyType "${def.bodyType}"`);
    }

    // Check each animation is supported
    for (const anim of def.animations || []) {
      const animName = resolveAnimName(anim);
      const hasAnim = (item.animations || []).includes(anim) || 
                      (item.animations || []).includes(animName);
      if (!hasAnim) {
        warnings.push(`Item ${layer.item} may not support animation "${anim}"`);
      }
    }

    // Check variant if specified
    if (layer.variant) {
      const variants = item.variants || [];
      if (variants.length > 0 && !variants.includes(layer.variant)) {
        errors.push(`Item ${layer.item} does not have variant "${layer.variant}". Available: ${variants.join(", ")}`);
      }
    }

    // Check color if specified
    if (layer.color && item.recolors && item.recolors.material) {
      // We will check palette colors at build time since loading palettes is expensive
      // Just warn if recolors are not supported
    } else if (layer.color && (!item.recolors || !item.recolors.material)) {
      warnings.push(`Item ${layer.item} does not support recoloring, but color "${layer.color}" was specified`);
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

// Validate a composition manifest
export function validateManifest(manifest, upstreamRoot) {
  const fs = require("fs");
  const errors = [];
  const warnings = [];

  for (const animLayer of manifest.layers) {
    if (animLayer.images.length === 0) {
      warnings.push(`Animation "${animLayer.animation}" has no resolved images`);
    }
    for (const img of animLayer.images) {
      if (!fs.existsSync(img.file)) {
        errors.push(`Missing file for ${animLayer.animation} zPos=${img.zPos}: ${img.file}`);
      }
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}
