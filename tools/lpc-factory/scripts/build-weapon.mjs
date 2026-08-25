// build-weapon.mjs — Build an LPC weapon sprite sheet.
// Usage: node scripts/build-weapon.mjs <weapon.yaml> [--output <dir>] [--publish]
// Weapon defs use { name, item, bodyType, variant, color?, animations } and are
// converted to a single-layer character manifest, then run through the same
// Node compositor pipeline as characters.

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

import { loadDefinition, normalizeWeaponDef, weaponToCharacterDef } from "./lib/definitions.mjs";
import { validateCharacterDef } from "./lib/validator.mjs";
import { buildManifest, manifestSummary } from "./lib/composer.mjs";
import { collectCredits, writeCredits } from "./lib/credits.mjs";
import { generateReport, writeReport, formatConsoleSummary } from "./lib/report.mjs";
import {
  composeAnimation, buildSheet, countOpaque, loadPngRgba,
} from "./lib/png-compositor.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const FACTORY_ROOT = path.resolve(__dirname, "..");

async function buildWeapon(definitionPath, options = {}) {
  const startTime = Date.now();
  const factoryRoot = FACTORY_ROOT;
  const upstreamRoot = path.join(factoryRoot, "upstream", "universal-lpc");

  console.log("Loading weapon definition:", definitionPath);
  const rawDef = loadDefinition(definitionPath);
  const weaponDef = normalizeWeaponDef(rawDef);
  const charDef = weaponToCharacterDef(weaponDef);

  if (options.animations) {
    charDef.animations = options.animations.split(",").map(a => a.trim());
    weaponDef.animations = charDef.animations;
  }

  console.log("Weapon: " + weaponDef.name + " (" + weaponDef.item + ")");
  if (weaponDef.variant) console.log("Variant: " + weaponDef.variant);
  console.log("Animations: " + charDef.animations.join(", "));

  const assetIndex = JSON.parse(fs.readFileSync(
    path.join(factoryRoot, "metadata", "asset-index.json"), "utf8"));

  const validation = validateCharacterDef(charDef, assetIndex);
  if (!validation.valid) {
    validation.errors.forEach(e => console.error("  ERROR: " + e));
    process.exit(1);
  }
  validation.warnings.forEach(w => console.warn("  warn: " + w));

  const manifest = buildManifest(charDef, assetIndex, upstreamRoot, factoryRoot);
  const summary = manifestSummary(manifest);
  console.log("Manifest: " + summary.totalImages + " images across " + summary.animations + " animations");

  // A weapon must resolve at least one image overall
  if (summary.totalImages === 0) {
    console.error("FATAL: no images resolved for weapon " + weaponDef.item +
      " (check bodyType/variant/animations)");
    process.exit(1);
  }

  const outputDir = options.output || path.join(factoryRoot, "build", weaponDef.name);
  const composeDir = path.join(outputDir, "composed");
  fs.mkdirSync(composeDir, { recursive: true });
  fs.writeFileSync(path.join(outputDir, "manifest.json"), JSON.stringify(manifest, null, 2));

  const composedList = [];
  for (const animEntry of manifest.layers) {
    if (animEntry.images.length === 0) {
      console.log("  skip " + animEntry.animation + " (no images)");
      continue;
    }
    const result = composeAnimation(animEntry, composeDir);
    composedList.push(result);
    console.log("  " + result.name + ": " + result.canvasW + "x" + result.canvasH +
      " (" + result.frames + "f x" + result.directions + "d @" + result.frameSize + "px)");
  }

  const sheetPng = path.join(outputDir, weaponDef.name + ".png");
  const sheetJson = path.join(outputDir, weaponDef.name + ".json");
  const info = buildSheet(composedList, sheetPng, sheetJson);
  console.log("Sheet: " + info.width + "x" + info.height);

  const opaque = countOpaque(loadPngRgba(sheetPng).data);
  if (opaque === 0) {
    console.error("FATAL: sheet is fully transparent");
    process.exit(1);
  }
  console.log("Verification: " + opaque + " opaque pixels");

  const credits = collectCredits(charDef, assetIndex);
  const creditsPath = path.join(outputDir, "CREDITS.md");
  writeCredits(creditsPath, weaponDef.name, credits);
  console.log("Credits: " + credits.length + " entries");

  const duration = Date.now() - startTime;
  const report = generateReport({
    characterName: weaponDef.name,
    bodyType: weaponDef.bodyType,
    animations: composedList.map(c => c.name),
    itemCount: 1,
    totalImages: summary.totalImages,
    outputFiles: [sheetPng, sheetJson, creditsPath],
    creditsCount: credits.length,
    authorCount: new Set(credits.flatMap(c => c.authors)).size,
    licenseCount: new Set(credits.flatMap(c => c.licenses)).size,
    duration,
    success: true,
    errors: [],
    warnings: validation.warnings,
  });
  const reportPath = path.join(outputDir, "build-report.json");
  writeReport(reportPath, report);
  console.log(formatConsoleSummary(report));

  if (options.publish) {
    const publishDir = path.join(factoryRoot, "..", "..", "art", "sprites", "lpc");
    fs.mkdirSync(publishDir, { recursive: true });
    fs.copyFileSync(sheetPng, path.join(publishDir, weaponDef.name + ".png"));
    fs.copyFileSync(sheetJson, path.join(publishDir, weaponDef.name + ".json"));
    fs.copyFileSync(creditsPath, path.join(publishDir, weaponDef.name + "-CREDITS.md"));
    console.log("Published to:", publishDir);
  }

  return report;
}

function parseArgs(argv) {
  const args = argv.slice(2);
  const options = {};
  let definitionPath = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--output" || args[i] === "-o") options.output = args[++i];
    else if (args[i] === "--animations" || args[i] === "-a") options.animations = args[++i];
    else if (args[i] === "--publish") options.publish = true;
    else if (args[i] === "--help" || args[i] === "-h") {
      console.log("Usage: node scripts/build-weapon.mjs <weapon.yaml> [--output <dir>] [--animations ...] [--publish]");
      process.exit(0);
    } else if (!args[i].startsWith("-")) definitionPath = args[i];
  }
  if (!definitionPath) {
    console.error("Error: No weapon definition specified");
    process.exit(1);
  }
  return { definitionPath, options };
}

const { definitionPath, options } = parseArgs(process.argv);
buildWeapon(definitionPath, options).catch(err => {
  console.error("Fatal error:", err.message);
  process.exit(1);
});
