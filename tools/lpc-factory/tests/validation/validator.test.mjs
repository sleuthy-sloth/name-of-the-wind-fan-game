// validator.test.mjs — validateCharacterDef against the real asset index
import test from "node:test";
import assert from "node:assert/strict";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

import { loadDefinition, normalizeCharacterDef } from "../../scripts/lib/definitions.mjs";
import { validateCharacterDef } from "../../scripts/lib/validator.mjs";
import { buildRecolorMap } from "../../scripts/lib/palettes.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..", "..");
const assetIndex = JSON.parse(fs.readFileSync(
  path.join(ROOT, "metadata", "asset-index.json"), "utf8"));

test("factory_test definition validates cleanly", () => {
  const raw = loadDefinition(path.join(ROOT, "definitions", "characters", "factory_test.yaml"));
  const def = normalizeCharacterDef(raw);
  const result = validateCharacterDef(def, assetIndex);
  assert.deepEqual(result.errors, []);
});

test("unknown catalog item is an error", () => {
  const def = normalizeCharacterDef({
    name: "x",
    layers: [{ item: "definitely.not.an.item" }],
  });
  const result = validateCharacterDef(def, assetIndex);
  assert.equal(result.valid, false);
  assert.ok(result.errors.some(e => e.includes("Catalog item not found")));
});

test("unknown variant is an error", () => {
  const def = normalizeCharacterDef({
    name: "x",
    animations: ["slash_128"],
    layers: [{ item: "weapon.arming_sword", variant: "unobtanium" }],
  });
  const result = validateCharacterDef(def, assetIndex);
  assert.equal(result.valid, false);
  assert.ok(result.errors.some(e => e.includes("variant \"unobtanium\"")));
});

test("invalid bodyType is an error", () => {
  const def = normalizeCharacterDef({ name: "x", bodyType: "giant" });
  const result = validateCharacterDef(def, assetIndex);
  assert.equal(result.valid, false);
  assert.ok(result.errors.some(e => e.includes("Invalid bodyType")));
});

test("buildRecolorMap maps shade-by-shade and skips identical shades", () => {
  const map = buildRecolorMap(
    ["#000000", "#111111"],
    ["#ff0000", "#111111"]);
  assert.deepEqual(map, { "#000000": "#ff0000" });
});
