// Validates the authored metadata files (requirements.json + licenses.json)
// against the pipeline invariants. Run via `npm test`.
import test from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import {
  SOURCES, loadRegistry, loadRequirements,
  isValidLogicalId, outputStem, eventNumbering,
} from "../scripts/lib/common.mjs";

const ALLOWED_DIRS = new Set([
  "music/menu", "music/ruh", "music/tarbean", "music/university", "music/imre",
  "music/underthing", "music/chandrian", "music/combat", "music/travel",
  "music/emotional",
  "ambience/forest", "ambience/city", "ambience/tarbean", "ambience/university",
  "ambience/archives", "ambience/underthing", "ambience/tavern",
  "ambience/weather", "ambience/fire", "ambience/crowd",
  "sfx/combat", "sfx/weapons", "sfx/footsteps", "sfx/clothing", "sfx/doors",
  "sfx/objects", "sfx/books", "sfx/coins", "sfx/ui", "sfx/sympathy",
  "sfx/naming", "sfx/animals", "sfx/environment",
  "instruments/lute",
]);

function entriesOf(reqs, group) {
  const section = reqs[group] ?? {};
  return Array.isArray(section) ? section : Object.values(section).flat();
}

test("requirements catalog is well-formed and collision-free", () => {
  const reqs = loadRequirements();
  const ids = [];
  for (const group of ["music", "ambience", "sfx"]) {
    for (const r of entriesOf(reqs, group)) {
      assert.ok(isValidLogicalId(r.id), `bad id: ${r.id}`);
      assert.ok(ALLOWED_DIRS.has(r.dir), `id ${r.id} targets unknown dir: ${r.dir}`);
      assert.ok(["standard", "approval"].includes(r.review), `id ${r.id} bad review policy`);
      ids.push(r.id);
    }
  }
  assert.equal(new Set(ids).size, ids.length, "duplicate requirement ids");
  // Plan s11 music list must all be present:
  for (const id of [
    "MUS_MENU_MAIN", "MUS_RUH_CAMP", "MUS_RUH_TRAVEL", "MUS_TARBEAN",
    "MUS_UNIVERSITY_DAY", "MUS_UNIVERSITY_NIGHT", "MUS_ARCHIVES",
    "MUS_UNDERTHING", "MUS_IMRE", "MUS_EOLIAN", "MUS_AURI", "MUS_CHANDRIAN",
    "MUS_COMBAT_STANDARD", "MUS_COMBAT_DANGER", "MUS_BOSS_DRACCUS",
    "MUS_EMOTIONAL_LOSS", "MUS_TRAVEL", "MUS_WAYSTONE",
  ]) {
    assert.ok(ids.includes(id), `missing required music id ${id}`);
  }
});

test("every registered event maps to a requirement, dir, and existing originals", () => {
  const reg = loadRegistry();
  const reqs = loadRequirements();
  const byId = new Map();
  for (const group of ["music", "ambience", "sfx"]) {
    for (const r of entriesOf(reqs, group)) byId.set(r.id, r);
  }
  const targetOwners = new Map(); // production path -> asset id
  const numbering = eventNumbering(reg);

  for (const asset of reg.assets) {
    assert.ok(asset.source?.creator && asset.source?.url, `${asset.id} provenance incomplete`);
    assert.ok(asset.license?.name, `${asset.id} missing license name`);
    assert.ok(
      ["pending", "approved", "rejected"].includes(asset.review?.status),
      `${asset.id} invalid review status`
    );
    assert.ok(
      existsSync(SOURCES("licenses", `${asset.id}.json`)),
      `${asset.id} missing license evidence file`
    );
    for (const [eventId, mappings] of Object.entries(asset.events ?? {})) {
      assert.ok(isValidLogicalId(eventId), `${asset.id}: bad event id ${eventId}`);
      const req = byId.get(eventId);
      assert.ok(req, `${asset.id}: event ${eventId} has no requirement`);
      mappings.forEach((rel, i) => {
        assert.ok(existsSync(SOURCES("original", rel)), `${asset.id}: original missing ${rel}`);
        // Cross-asset contributors continue the same variant pool; the shared
        // numbering must keep every production path unique.
        const seq = numbering.get(`${asset.id}|${eventId}|${i}`);
        const target = `${req.dir}/${outputStem(eventId, seq)}`;
        const owner = targetOwners.get(target);
        if (owner) {
          assert.fail(`production target collision at ${target} (${owner} vs ${asset.id})`);
        } else {
          targetOwners.set(target, asset.id);
        }
      });
    }
  }
});
