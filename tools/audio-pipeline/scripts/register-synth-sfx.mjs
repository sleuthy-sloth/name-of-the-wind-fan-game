// register-synth-sfx.mjs — Merge sources/original/notw_synthesized_sfx/manifest.json
// (produced by scripts/tools/synth_sfx.py) into metadata/licenses.json as a
// project-original asset entry. Idempotent: re-running replaces this entry.
//
// Usage: node scripts/register-synth-sfx.mjs

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

import { loadRegistry, saveRegistry, SOURCES } from "./lib/common.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT = path.resolve(__dirname, "..");
const MANIFEST = path.join(ROOT, "sources", "original", "notw_synthesized_sfx", "manifest.json");

const ASSET_ID = "notw_synthesized_sfx";
const manifest = JSON.parse(fs.readFileSync(MANIFEST, "utf8"));
const eventIds = Object.keys(manifest);
if (eventIds.length === 0) {
  console.error("manifest.json has no events — run synth_sfx.py first");
  process.exit(1);
}

// Verify every original file exists before registering
const missing = [];
for (const eid of eventIds) {
  for (const f of manifest[eid].files) {
    if (!fs.existsSync(SOURCES("original", "notw_synthesized_sfx", f))) {
      missing.push(f);
    }
  }
}
if (missing.length > 0) {
  console.error("Missing original files:\n  - " + missing.join("\n  - "));
  process.exit(1);
}

const reg = loadRegistry();
const events = {};
const original = [];
for (const eid of eventIds) {
  events[eid] = manifest[eid].files.map(f => "notw_synthesized_sfx/" + f);
  // originals are registered relative to sources/original/
  original.push(...manifest[eid].files.map(f => "notw_synthesized_sfx/" + f));
}

const entry = {
  id: ASSET_ID,
  type: "sfx",
  policy: "project-original",
  source: {
    site: "in-repo",
    creator: "NOTW contributors",
    title: "Procedurally synthesized SFX one-shots and weather layers (scripts/tools/synth_sfx.py)",
    url: "scripts/tools/synth_sfx.py",
    downloadDate: new Date().toISOString().slice(0, 10),
  },
  license: {
    name: "Project-original (CC BY-NC-SA 4.0 per LICENSE-ASSETS.md)",
    url: "../../LICENSE-ASSETS.md",
    attributionRequired: false,
  },
  review: {
    status: "approved",
    reviewer: null,
    notes: "Self-authored deterministic synthesis; standard-review SFX only. Music/crowd/signature sounds intentionally excluded.",
  },
  original,
  events,
};

const idx = reg.assets.findIndex(a => a.id === ASSET_ID);
if (idx >= 0) reg.assets[idx] = entry;
else reg.assets.push(entry);
saveRegistry(reg);

console.log(`Registered ${ASSET_ID}: ${eventIds.length} events, ${original.length} files` +
  (idx >= 0 ? " (replaced existing entry)" : ""));
