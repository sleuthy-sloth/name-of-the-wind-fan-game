// build-group.mjs — Build every member of a group definition and aggregate
// a shared report + merged credits.
// Group format (definitions/groups/*.yaml):
//   name: ruh_crew
//   description: optional
//   members:
//     - definitions/characters/factory_test.yaml    # paths relative to factory root
//     - definitions/weapons/lpc_sword_test.yaml
// Members are still written to their own build/<member-name> dirs so
// validate-build --all keeps working; the group adds:
//   build/groups/<name>/group-report.json
//   build/groups/<name>/CREDITS.md          (merged, deduped)
//
// Usage: node scripts/build-group.mjs <group.yaml|name> [--publish]

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

import { loadDefinition } from "./lib/definitions.mjs";
import { collectCredits, getUniqueAuthors } from "./lib/credits.mjs";
import { buildCharacter } from "./build-character.mjs";
import { buildWeapon } from "./build-weapon.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const FACTORY_ROOT = path.resolve(__dirname, "..");

function findGroup(identifier) {
  const direct = path.resolve(identifier);
  if (fs.existsSync(direct)) return { def: loadDefinition(direct), source: direct };
  for (const ext of [".yaml", ".yml", ".json"]) {
    const p = path.join(FACTORY_ROOT, "definitions", "groups", identifier + ext);
    if (fs.existsSync(p)) return { def: loadDefinition(p), source: p };
  }
  console.error("Group not found: " + identifier);
  process.exit(1);
}

function parseArgs(argv) {
  const args = argv.slice(2);
  const options = {};
  let target = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--publish") options.publish = true;
    else if (args[i] === "--help" || args[i] === "-h") {
      console.log("Usage: node scripts/build-group.mjs <group.yaml|name> [--publish]");
      process.exit(0);
    } else if (!args[i].startsWith("-")) target = args[i];
  }
  if (!target) {
    console.error("Error: No group specified");
    process.exit(1);
  }
  return { target, options };
}

const { target, options } = parseArgs(process.argv);
const { def: group, source } = findGroup(target);
if (!group.name || !Array.isArray(group.members) || group.members.length === 0) {
  console.error("Invalid group: needs 'name' and non-empty 'members' array");
  process.exit(1);
}

console.log("=== GROUP " + group.name + " (" + group.members.length + " members) ===");

const assetIndex = JSON.parse(fs.readFileSync(
  path.join(FACTORY_ROOT, "metadata", "asset-index.json"), "utf8"));

const results = [];
let failures = 0;
for (const memberRel of group.members) {
  const memberPath = path.resolve(FACTORY_ROOT, memberRel);
  if (!fs.existsSync(memberPath)) {
    console.error("FAIL  " + memberRel + ": file missing");
    results.push({ member: memberRel, success: false, error: "file missing" });
    failures++;
    continue;
  }
  const raw = loadDefinition(memberPath);
  const kind = raw.item !== undefined && raw.layers === undefined ? "weapon" : "character";
  console.log("\n--- member: " + memberRel + " (" + kind + ") ---");
  try {
    const buildFn = kind === "weapon" ? buildWeapon : buildCharacter;
    const report = await buildFn(memberPath, { publish: options.publish });
    results.push({ member: memberRel, kind, success: true,
      character: report.character,
      images: report.summary.totalImagesComposed });
  } catch (err) {
    console.error("BUILD FAILED: " + err.message);
    results.push({ member: memberRel, kind, success: false, error: err.message });
    failures++;
  }
}

// Merged credits across all successful members
const mergedCreditsMap = new Map();
for (const r of results) {
  if (!r.success) continue;
  const defPath = path.resolve(FACTORY_ROOT, r.member);
  const def = loadDefinition(defPath);
  const normalized = r.kind === "weapon"
    ? (() => { const w = def; return {
        name: w.name, bodyType: w.bodyType || "male",
        animations: [], layers: [{ item: w.item, color: w.color || null, variant: w.variant || null }],
      }; })()
    : def;
  for (const c of collectCredits(normalized, assetIndex)) {
    mergedCreditsMap.set(c.item + ":" + c.file, c);
  }
}
const mergedCredits = [...mergedCreditsMap.values()];

const outDir = path.join(FACTORY_ROOT, "build", "groups", group.name);
fs.mkdirSync(outDir, { recursive: true });

const groupReport = {
  timestamp: new Date().toISOString(),
  group: group.name,
  source: path.relative(FACTORY_ROOT, source),
  success: failures === 0,
  members: results,
  totals: {
    members: results.length,
    succeeded: results.filter(r => r.success).length,
    failed: failures,
    imagesComposed: results.reduce((s, r) => s + (r.images || 0), 0),
    uniqueCreditEntries: mergedCredits.length,
    uniqueAuthors: new Set(mergedCredits.flatMap(c => c.authors)).size,
  },
};
fs.writeFileSync(path.join(outDir, "group-report.json"),
  JSON.stringify(groupReport, null, 2));

if (mergedCredits.length > 0) {
  let md = "# Credits: " + group.name + "\n\n## Licenses\n\n" +
    [...new Set(mergedCredits.flatMap(c => c.licenses))].map(l => "- " + l).join("\n") +
    "\n\n## Authors\n\n";
  for (const a of getUniqueAuthors(mergedCredits)) {
    md += "- " + a.name + " (" + a.items.length + " items)\n";
  }
  md += "\n## Detailed Credits\n\n";
  for (const c of mergedCredits) {
    md += "### " + c.itemName + " (`" + c.item + "`)\n" +
      "- Authors: " + c.authors.join(", ") + "\n" +
      "- Licenses: " + c.licenses.join(", ") + "\n\n";
  }
  fs.writeFileSync(path.join(outDir, "CREDITS.md"), md, "utf8");
}

console.log("\n=== GROUP SUMMARY: " + group.name + " ===");
console.log("Members: " + groupReport.totals.succeeded + "/" +
  groupReport.totals.members + " built, " +
  groupReport.totals.imagesComposed + " images composed");
console.log("Report: " + path.relative(FACTORY_ROOT, path.join(outDir, "group-report.json")));
process.exit(failures > 0 ? 1 : 0);
