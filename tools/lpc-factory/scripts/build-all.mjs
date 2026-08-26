// build-all.mjs — Build every character, weapon, and generated definition in
// the factory. Writes an aggregate report to build/build-all-report.json and
// exits non-zero if any build fails.
//
// Usage:
//   node scripts/build-all.mjs [--only <substring>] [--publish] [--animations a,b]
//   node scripts/build-all.mjs --check      # list what would be built, no builds

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

import { loadDefinition } from "./lib/definitions.mjs";
import { buildCharacter } from "./build-character.mjs";
import { buildWeapon } from "./build-weapon.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const FACTORY_ROOT = path.resolve(__dirname, "..");

function discoverDefinitions() {
  const entries = [];
  const groups = [
    ["character", "definitions/characters"],
    ["weapon", "definitions/weapons"],
    ["generated", "definitions/generated"],
  ];
  for (const [kind, rel] of groups) {
    const dir = path.join(FACTORY_ROOT, rel);
    if (!fs.existsSync(dir)) continue;
    for (const entry of fs.readdirSync(dir).sort()) {
      if (!/\.(ya?ml|json)$/i.test(entry)) continue;
      entries.push({ kind, relPath: path.join(rel, entry) });
    }
  }
  return entries;
}

function parseArgs(argv) {
  const args = argv.slice(2);
  const options = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--only") options.only = args[++i];
    else if (args[i] === "--publish") options.publish = true;
    else if (args[i] === "--animations" || args[i] === "-a") options.animations = args[++i];
    else if (args[i] === "--check") options.check = true;
    else if (args[i] === "--help" || args[i] === "-h") {
      console.log("Usage: node scripts/build-all.mjs [--only <substr>] [--publish] [--animations idle,walk] [--check]");
      process.exit(0);
    }
  }
  return options;
}

const options = parseArgs(process.argv);
let targets = discoverDefinitions();

if (options.only) {
  targets = targets.filter(t => t.relPath.includes(options.only));
}

console.log("Discovered " + targets.length + " definition(s):");
for (const t of targets) console.log("  [" + t.kind + "] " + t.relPath);

if (targets.length === 0) {
  console.error("Nothing to build.");
  process.exit(1);
}
if (options.check) {
  console.log("CHECK: dry run only, no builds executed.");
  process.exit(0);
}

const results = [];
let failures = 0;
const startedAt = Date.now();

for (const t of targets) {
  const fullPath = path.join(FACTORY_ROOT, t.relPath);
  console.log("\n=== BUILD " + t.relPath + " (" + t.kind + ") ===");
  try {
    const raw = loadDefinition(fullPath);
    // Skip definitions that are intentionally not buildable standalone
    if (raw.build === false) {
      console.log("SKIP: marked build: false");
      results.push({ ...t, success: true, skipped: true });
      continue;
    }
    const buildFn = t.kind === "weapon" ? buildWeapon : buildCharacter;
    const report = await buildFn(fullPath, {
      publish: options.publish,
      animations: options.animations,
    });
    results.push({ ...t, success: true, character: report.character,
      images: report.summary.totalImagesComposed,
      durationMs: report.summary.durationMs });
  } catch (err) {
    console.error("BUILD FAILED: " + err.message);
    results.push({ ...t, success: false, error: err.message });
    failures++;
  }
}

const aggregate = {
  timestamp: new Date().toISOString(),
  durationMs: Date.now() - startedAt,
  success: failures === 0,
  totals: {
    discovered: targets.length,
    built: results.filter(r => r.success && !r.skipped).length,
    skipped: results.filter(r => r.skipped).length,
    failed: failures,
    imagesComposed: results.reduce((s, r) => s + (r.images || 0), 0),
  },
  results,
};
const reportPath = path.join(FACTORY_ROOT, "build", "build-all-report.json");
fs.mkdirSync(path.dirname(reportPath), { recursive: true });
fs.writeFileSync(reportPath, JSON.stringify(aggregate, null, 2));

console.log("\n=== BUILD-ALL SUMMARY ===");
console.log("Built: " + aggregate.totals.built + ", skipped: " +
  aggregate.totals.skipped + ", failed: " + aggregate.totals.failed +
  ", images: " + aggregate.totals.imagesComposed +
  ", time: " + (aggregate.durationMs / 1000).toFixed(1) + "s");
console.log("Report: build/build-all-report.json");
process.exit(failures > 0 ? 1 : 0);
