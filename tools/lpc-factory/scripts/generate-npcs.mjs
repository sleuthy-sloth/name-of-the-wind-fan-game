// generate-npcs.mjs — Generate deterministic NPC character definitions from
// archetype files (definitions/npc-archetypes/*.yaml).
// Usage:
//   node scripts/generate-npcs.mjs --list
//   node scripts/generate-npcs.mjs <archetype.yaml|name> [--count N] [--seed S]
//        [--out-dir DIR] [--body-types male,female] [--build] [--publish]

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

import { loadDefinition, loadDefinitionsFromDir } from "./lib/definitions.mjs";
import { generateNpcs, writeNpcDefs, validateArchetype } from "./lib/npc-generator.mjs";
import { buildCharacter } from "./build-character.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const FACTORY_ROOT = path.resolve(__dirname, "..");

function findArchetype(identifier) {
  const direct = path.resolve(identifier);
  if (fs.existsSync(direct)) return { def: loadDefinition(direct), source: direct };
  const dir = path.join(FACTORY_ROOT, "definitions", "npc-archetypes");
  for (const ext of [".yaml", ".yml", ".json"]) {
    const p = path.join(dir, identifier + ext);
    if (fs.existsSync(p)) return { def: loadDefinition(p), source: p };
  }
  console.error("Archetype not found: " + identifier);
  console.error("Looked in: " + dir);
  process.exit(1);
}

function listArchetypes() {
  const dir = path.join(FACTORY_ROOT, "definitions", "npc-archetypes");
  if (!fs.existsSync(dir)) {
    console.log("No npc-archetypes directory at " + dir);
    return;
  }
  for (const def of loadDefinitionsFromDir(dir)) {
    if (def._error) {
      console.log("  [PARSE ERROR] " + path.basename(def._sourceFile) + ": " + def._error);
      continue;
    }
    console.log("  " + def.name +
      " — count=" + (def.count ?? "?") +
      ", seed=" + (def.seed ?? "(default)") +
      ", slots=" + ((def.slots || []).length));
  }
}

function parseArgs(argv) {
  const args = argv.slice(2);
  const options = {};
  let identifier = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--list") options.list = true;
    else if (args[i] === "--count") options.count = parseInt(args[++i], 10);
    else if (args[i] === "--seed") options.seed = args[++i];
    else if (args[i] === "--out-dir" || args[i] === "-o") options.outDir = args[++i];
    else if (args[i] === "--body-types") options.bodyTypes = args[++i].split(",").map(s => s.trim());
    else if (args[i] === "--build") options.build = true;
    else if (args[i] === "--publish") { options.build = true; options.publish = true; }
    else if (args[i] === "--help" || args[i] === "-h") {
      console.log("Usage: node scripts/generate-npcs.mjs <archetype> [--count N] [--seed S] [--out-dir DIR] [--body-types male,female] [--build] [--publish]");
      console.log("       node scripts/generate-npcs.mjs --list");
      process.exit(0);
    } else if (!args[i].startsWith("-")) identifier = args[i];
  }
  return { identifier, options };
}

const { identifier, options } = parseArgs(process.argv);

if (options.list) {
  listArchetypes();
} else {
  if (!identifier) {
    console.error("Error: No archetype specified (or use --list)");
    process.exit(1);
  }
  const assetIndex = JSON.parse(fs.readFileSync(
    path.join(FACTORY_ROOT, "metadata", "asset-index.json"), "utf8"));
  const { def: archetype, source } = findArchetype(identifier);
  console.log("Archetype:", path.basename(source));

  const validation = validateArchetype(archetype, assetIndex);
  if (!validation.valid) {
    console.error("Validation errors:");
    validation.errors.forEach(e => console.error("  - " + e));
    process.exit(1);
  }

  const npcs = generateNpcs(archetype, assetIndex, {
    count: options.count,
    seed: options.seed,
    bodyTypes: options.bodyTypes,
  });
  console.log("Generated " + npcs.length + " NPC definitions (deterministic)");
  for (const n of npcs) {
    console.log("  " + n.name + " [" + n.bodyType + "] " +
      n.layers.map(l => l.item).join(", "));
  }

  const outDir = options.outDir || path.join(FACTORY_ROOT, "definitions", "generated");
  const written = writeNpcDefs(npcs, outDir);
  console.log("Wrote " + written.length + " definitions to " + outDir);

  if (options.build) {
    let failed = 0;
    for (const filePath of written) {
      try {
        await buildCharacter(filePath, { publish: options.publish });
      } catch (err) {
        console.error("BUILD FAILED " + path.basename(filePath) + ": " + err.message);
        failed++;
      }
    }
    if (failed > 0) process.exit(1);
  }
}
