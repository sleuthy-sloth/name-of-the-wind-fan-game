import test from "node:test";
import assert from "node:assert/strict";
import { classifyLicense, isValidLogicalId, outputStem, eventNumbering } from "../scripts/lib/common.mjs";

test("classifyLicense accepts CC0 variants", () => {
  assert.equal(classifyLicense("CC0"), "tier1");
  assert.equal(classifyLicense("CC0-1.0"), "tier1");
  assert.equal(classifyLicense("Creative Commons Zero / Public Domain"), "tier1");
  assert.equal(classifyLicense("Pixabay Content License"), "tier1");
});

test("classifyLicense accepts clean CC-BY as tier2", () => {
  assert.equal(classifyLicense("CC-BY-4.0"), "tier2");
  assert.equal(classifyLicense("CC BY 3.0"), "tier2");
  assert.equal(classifyLicense("cc-by"), "tier2");
});

test("classifyLicense rejects non-commercial and ND licenses", () => {
  assert.equal(classifyLicense("CC-BY-NC"), "prohibited");
  assert.equal(classifyLicense("CC BY-NC 4.0"), "prohibited");
  assert.equal(classifyLicense("CC-BY-NC-SA 4.0"), "prohibited");
  assert.equal(classifyLicense("CC-BY-ND"), "prohibited");
  assert.equal(classifyLicense("Personal use only"), "prohibited");
  assert.equal(classifyLicense("CC0 + NC"), "prohibited");
});

test("classifyLicense parks share-alike/OGA/GPL in tier3", () => {
  assert.equal(classifyLicense("CC-BY-SA 3.0"), "tier3");
  assert.equal(classifyLicense("OGA-BY"), "tier3");
  assert.equal(classifyLicense("GPL v3 audio"), "tier3");
});

test("classifyLicense never infers from marketing claims", () => {
  assert.equal(classifyLicense("royalty free music"), "unknown");
  assert.equal(classifyLicense(""), "unknown");
  assert.equal(classifyLicense(undefined), "unknown");
});

test("isValidLogicalId enforces prefixed upper-snake IDs", () => {
  assert.ok(isValidLogicalId("SFX_PAGE_TURN"));
  assert.ok(isValidLogicalId("MUS_UNIVERSITY_DAY"));
  assert.ok(isValidLogicalId("AMB_TARBEAN_NIGHT"));
  assert.ok(isValidLogicalId("INSTR_LUTE_NOTE_D3"));
  assert.ok(!isValidLogicalId("page_turn"));
  assert.ok(!isValidLogicalId("SFX_lower_case"));
  assert.ok(!isValidLogicalId("SFX_"));
  assert.ok(!isValidLogicalId(""));
});

test("outputStem follows the plan s35 naming convention", () => {
  assert.equal(outputStem("SFX_FOOT_STONE", 1), "foot_stone_01");
  assert.equal(outputStem("SFX_SWORD_SWING_LIGHT", 3), "sword_swing_light_03");
  // Events that already carry their own number reuse it verbatim:
  assert.equal(outputStem("SFX_PAGE_TURN_01", 1), "page_turn_01");
  assert.equal(outputStem("AMB_TARBEAN_NIGHT", 1), "tarbean_night_01");
  assert.equal(outputStem("MUS_STING_ENDCARD", 1), "sting_endcard_01");
});

test("eventNumbering continues variant pools across contributing assets", () => {
  const reg = {
    assets: [
      { id: "a", events: { SFX_FOOT_STONE: ["x.wav"] } },
      { id: "b", events: { SFX_FOOT_STONE: ["y1.wav", "y2.wav"], MUS_TARBEAN: ["z.wav"] } },
    ],
  };
  const numbering = eventNumbering(reg);
  assert.equal(numbering.get("a|SFX_FOOT_STONE|0"), 1);
  // Second contributor CONTINUES the pool instead of colliding:
  assert.equal(numbering.get("b|SFX_FOOT_STONE|0"), 2);
  assert.equal(numbering.get("b|SFX_FOOT_STONE|1"), 3);
  assert.equal(numbering.get("b|MUS_TARBEAN|0"), 1);
});
