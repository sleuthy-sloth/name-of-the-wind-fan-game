// definitions.mjs — Parse and validate character/weapon definitions.
// Supports YAML and JSON.

import fs from "fs";
import path from "path";
import yaml from "js-yaml";

export function loadDefinition(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const raw = fs.readFileSync(filePath, "utf8");
  if (ext === ".yaml" || ext === ".yml") return yaml.load(raw);
  if (ext === ".json") return JSON.parse(raw);
  throw new Error("Unsupported definition format: " + ext);
}

export function loadDefinitionsFromDir(dirPath) {
  const defs = [];
  if (!fs.existsSync(dirPath)) return defs;
  for (const entry of fs.readdirSync(dirPath)) {
    const ext = path.extname(entry).toLowerCase();
    if (ext === ".yaml" || ext === ".yml" || ext === ".json") {
      const fullPath = path.join(dirPath, entry);
      try {
        const def = loadDefinition(fullPath);
        def._sourceFile = fullPath;
        defs.push(def);
      } catch (e) {
        defs.push({ _sourceFile: fullPath, _error: e.message });
      }
    }
  }
  return defs;
}

export function normalizeCharacterDef(raw) {
  const def = {
    name: raw.name,
    bodyType: raw.bodyType || "male",
    animations: raw.animations || ["idle", "walk"],
    layers: [],
  };
  if (raw.layers && Array.isArray(raw.layers)) {
    def.layers = raw.layers.map(l => ({
      item: l.item,
      color: l.color || null,
      variant: l.variant || null,
      palette: l.palette || null,
    }));
  }
  return def;
}

export function normalizeWeaponDef(raw) {
  return {
    name: raw.name,
    bodyType: raw.bodyType || "male",
    variant: raw.variant || null,
    animations: raw.animations ||
      ["walk", "idle", "combat_idle", "hurt", "slash_128", "backslash_128", "halfslash_128"],
    item: raw.item,
    color: raw.color || null,
  };
}

export function weaponToCharacterDef(weaponDef) {
  return {
    name: weaponDef.name,
    bodyType: weaponDef.bodyType,
    animations: weaponDef.animations,
    layers: [{ item: weaponDef.item, color: weaponDef.color, variant: weaponDef.variant }],
  };
}
