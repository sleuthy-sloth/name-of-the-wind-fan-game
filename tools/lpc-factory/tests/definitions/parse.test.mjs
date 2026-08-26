// parse.test.mjs — Definition loading and normalization
import test from "node:test";
import assert from "node:assert/strict";
import path from "path";
import { fileURLToPath } from "url";

import {
  loadDefinition, loadDefinitionsFromDir,
  normalizeCharacterDef, normalizeWeaponDef, weaponToCharacterDef,
} from "../../scripts/lib/definitions.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..", "..");
const CHAR_DIR = path.join(ROOT, "definitions", "characters");
const WEAPON_PATH = path.join(ROOT, "definitions", "weapons", "lpc_sword_test.yaml");

test("loads character YAML definition", () => {
  const def = loadDefinition(path.join(CHAR_DIR, "factory_test.yaml"));
  assert.equal(def.name, "factory_test");
  assert.equal(def.bodyType, "male");
  assert.deepEqual(def.animations, ["idle", "walk"]);
  assert.equal(def.layers.length, 5);
});

test("normalizeCharacterDef applies defaults", () => {
  const def = normalizeCharacterDef({ name: "x" });
  assert.equal(def.bodyType, "male");
  assert.deepEqual(def.animations, ["idle", "walk"]);
  assert.deepEqual(def.layers, []);
});

test("normalizeCharacterDef preserves layer fields", () => {
  const def = normalizeCharacterDef({
    name: "x",
    layers: [{ item: "hair.bob", color: "black", variant: "v2" }],
  });
  assert.deepEqual(def.layers[0], { item: "hair.bob", color: "black", variant: "v2", palette: null });
});

test("weapon definition normalizes and converts to character def", () => {
  const raw = loadDefinition(WEAPON_PATH);
  const w = normalizeWeaponDef(raw);
  assert.equal(w.item, "weapon.arming_sword");
  assert.equal(w.variant, "iron");
  assert.ok(w.animations.includes("slash_128"));

  const char = weaponToCharacterDef(w);
  assert.equal(char.name, w.name);
  assert.equal(char.layers.length, 1);
  assert.equal(char.layers[0].item, "weapon.arming_sword");
});

test("loadDefinitionsFromDir skips non-definition files and reports parse errors", () => {
  const defs = loadDefinitionsFromDir(CHAR_DIR);
  assert.ok(defs.length >= 2);
  for (const d of defs) assert.equal(d._error, undefined, d._sourceFile || "?");
});
