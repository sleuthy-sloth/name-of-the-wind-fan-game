// npc-generation.test.mjs — Deterministic pool-based NPC generation
import test from "node:test";
import assert from "node:assert/strict";
import fs from "fs";
import os from "os";
import path from "path";
import { fileURLToPath } from "url";

import {
  hashString, mulberry32, validateArchetype,
  generateNpcs, writeNpcDefs,
} from "../../scripts/lib/npc-generator.mjs";
import { loadDefinition } from "../../scripts/lib/definitions.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..", "..");
const assetIndex = JSON.parse(fs.readFileSync(
  path.join(ROOT, "metadata", "asset-index.json"), "utf8"));

function makeArchetype() {
  return {
    name: "test_crew",
    count: 4,
    seed: 42,
    bodyTypes: ["male", "female"],
    animations: ["idle", "walk"],
    slots: [
      { slotName: "hair", pool: [
        { item: "hair.page", colors: ["black", "brown"] },
        { item: "hair.balding" },
      ] },
      { slotName: "shirt", pool: [{ item: "clothes.longsleeve", colors: ["blue", "red"] }] },
    ],
  };
}

test("hashString is stable and well-distributed enough for seeds", () => {
  assert.equal(hashString("abc"), hashString("abc"));
  assert.notEqual(hashString("abc"), hashString("abd"));
});

test("mulberry32 is deterministic across instances", () => {
  const a = mulberry32(1234);
  const b = mulberry32(1234);
  for (let i = 0; i < 10; i++) assert.equal(a(), b());
});

test("archetype validation catches missing items and bad counts", () => {
  const bad = { ...makeArchetype(), slots: [{ pool: [{ item: "nope.nope" }] }] };
  let r = validateArchetype(bad, assetIndex);
  assert.equal(r.valid, false);
  assert.ok(r.errors.some(e => e.includes("not found")));

  r = validateArchetype({ ...makeArchetype(), count: 0 }, assetIndex);
  assert.equal(r.valid, false);

  r = validateArchetype(makeArchetype(), assetIndex);
  assert.deepEqual(r.errors, []);
});

test("generation is deterministic and respects count/bodyTypes/slots", () => {
  const run1 = generateNpcs(makeArchetype(), assetIndex);
  const run2 = generateNpcs(makeArchetype(), assetIndex);
  assert.deepEqual(run1, run2);
  assert.equal(run1.length, 4);
  for (const npc of run1) {
    assert.ok(["male", "female"].includes(npc.bodyType));
    assert.equal(npc.layers.length, 2); // one per slot
    assert.match(npc.name, /^test_crew_\d{2}$/);
  }
  // Different seed -> (almost certainly) different picks
  const other = generateNpcs({ ...makeArchetype(), seed: 43 }, assetIndex);
  assert.notDeepEqual(run1, other);
});

test("colors are only assigned when the catalog item supports recoloring", () => {
  const npcs = generateNpcs({
    name: "recolor_guard",
    count: 8,
    seed: 7,
    slots: [{ pool: [{ item: "hair.balding", colors: ["black"] }] }],
  }, assetIndex);
  const item = assetIndex.catalog["hair.balding"];
  const supports = Boolean(item.recolors && item.recolors.material);
  for (const n of npcs) {
    if (!supports) assert.equal(n.layers[0].color, undefined);
  }
});

test("variant-dir items map color pools onto valid variants", () => {
  // clothes.tunic has no recolor material; its colors are variant files.
  const npcs = generateNpcs({
    name: "variant_guard",
    count: 6,
    seed: 11,
    slots: [{ pool: [{ item: "clothes.tunic", colors: ["tan", "brown", "not_a_color"] }] }],
  }, assetIndex);
  const item = assetIndex.catalog["clothes.tunic"];
  assert.ok(!(item.recolors && item.recolors.material));
  for (const n of npcs) {
    assert.ok(item.variants.includes(n.layers[0].variant),
      "picked variant must exist: " + n.layers[0].variant);
  }
});

test("written YAML files round-trip through loadDefinition", () => {
  const npcs = generateNpcs(makeArchetype(), assetIndex);
  const outDir = fs.mkdtempSync(path.join(os.tmpdir(), "npc-gen-"));
  try {
    const written = writeNpcDefs(npcs, outDir);
    assert.equal(written.length, 4);
    const reloaded = loadDefinition(written[0]);
    assert.equal(reloaded.name, npcs[0].name);
    assert.equal(reloaded.layers.length, npcs[0].layers.length);
    for (let i = 0; i < reloaded.layers.length; i++) {
      assert.equal(reloaded.layers[i].item, npcs[0].layers[i].item);
      assert.equal(reloaded.layers[i].color ?? null, npcs[0].layers[i].color ?? null);
    }
  } finally {
    fs.rmSync(outDir, { recursive: true, force: true });
  }
});
