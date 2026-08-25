// build-character.mjs — Main CLI entry point for building LPC characters
// Pipeline: definition -> catalog validation -> composition manifest ->
// Node/pngjs compositing + recoloring -> game-ready sheet + JSON + credits.
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

import { loadDefinition, normalizeCharacterDef } from "./lib/definitions.mjs";
import { validateCharacterDef } from "./lib/validator.mjs";
import { buildManifest, manifestSummary } from "./lib/composer.mjs";
import { collectCredits, writeCredits } from "./lib/credits.mjs";
import { generateReport, writeReport, formatConsoleSummary } from "./lib/report.mjs";
import {
  composeAnimation, buildSheet, countOpaque,
} from "./lib/png-compositor.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const FACTORY_ROOT = path.resolve(__dirname, "..");

function generateLuaManifest(manifest, outputPath) {
  const parts = [];
  parts.push("return {");
  parts.push("  character = \"" + manifest.character + "\",");
  parts.push("  bodyType = \"" + manifest.bodyType + "\",");
  let rowOffset = 0;
  parts.push("  animations = {");
  for (const anim of manifest.layers) {
    parts.push("    {");
    parts.push("      name = \"" + anim.animation + "\",");
    parts.push("      rowOffset = " + rowOffset + ",");
    parts.push("      frameSize = " + anim.frameSize + ",");
    parts.push("      frames = " + anim.frames + ",");
    parts.push("      directions = " + anim.directions + ",");
    parts.push("      images = {");
    for (const img of anim.images) {
      const recolorStr = img.recolorMap ? formatRecolorMap(img.recolorMap) : "nil";
      parts.push("        { zPos = " + img.zPos + ", file = \"" + img.file + "\", recolorMap = " + recolorStr + " },");
    }
    parts.push("      }");
    parts.push("    },");
    rowOffset += anim.directions;
  }
  parts.push("  }");
  parts.push("}");
  fs.writeFileSync(outputPath, parts.join("\n"), "utf8");
  return outputPath;
}

function formatRecolorMap(map) {
  const entries = [];
  for (const [src, tgt] of Object.entries(map)) {
    entries.push("[\"" + src + "\"] = \"" + tgt + "\"");
  }
  return "{ " + entries.join(", ") + " }";
}

async function buildCharacter(definitionPath, options = {}) {
  const startTime = Date.now();
  const factoryRoot = FACTORY_ROOT;
  const upstreamRoot = path.join(factoryRoot, "upstream", "universal-lpc");

  console.log("Loading definition:", definitionPath);
  const rawDef = loadDefinition(definitionPath);
  const def = normalizeCharacterDef(rawDef);

  if (options.animations) {
    def.animations = options.animations.split(",").map(a => a.trim());
  }

  console.log("Character: " + def.name + " (" + def.bodyType + ")");
  console.log("Animations: " + def.animations.join(", "));
  console.log("Layers: " + def.layers.length);

  const assetIndexPath = path.join(factoryRoot, "metadata", "asset-index.json");
  const assetIndex = JSON.parse(fs.readFileSync(assetIndexPath, "utf8"));
  console.log("Asset index: " + assetIndex.itemCount + " items");

  const validation = validateCharacterDef(def, assetIndex);
  if (!validation.valid) {
    console.error("Validation errors:");
    validation.errors.forEach(e => console.error("  - " + e));
    process.exit(1);
  }
  if (validation.warnings.length > 0) {
    console.warn("Validation warnings:");
    validation.warnings.forEach(w => console.warn("  - " + w));
  }

  console.log("Building composition manifest...");
  const manifest = buildManifest(def, assetIndex, upstreamRoot, factoryRoot);
  const summary = manifestSummary(manifest);
  console.log("Manifest: " + summary.animations + " animations, " + summary.totalImages + " images");
  console.log("  " + summary.detail);

  const emptyAnims = manifest.layers.filter(l => l.images.length === 0);
  if (emptyAnims.length > 0) {
    console.warn("Animations with no resolved images:");
    emptyAnims.forEach(a => console.warn("  - " + a.animation));
  }

  const outputDir = options.output || path.join(factoryRoot, "build", def.name);
  const composeDir = path.join(outputDir, "composed");
  fs.mkdirSync(composeDir, { recursive: true });

  // Persist the JSON manifest for reproducibility
  fs.writeFileSync(path.join(outputDir, "manifest.json"),
    JSON.stringify(manifest, null, 2));

  // Compose each animation in Node (pngjs): recolor + alpha-composite layers
  console.log("Composing animations...");
  const composedList = [];
  for (const animEntry of manifest.layers) {
    const result = composeAnimation(animEntry, composeDir);
    composedList.push(result);
    console.log("  " + result.name + ": " + result.canvasW + "x" + result.canvasH +
      " (" + result.frames + " frames x " + result.directions + " dirs) -> " + path.basename(result.file));
  }

  // Combine into final game-ready sheet + JSON frame data
  console.log("Building final sheet...");
  const sheetPng = path.join(outputDir, def.name + ".png");
  const sheetJson = path.join(outputDir, def.name + ".json");
  const sheetInfo = buildSheet(composedList, sheetPng, sheetJson);
  console.log("Sheet: " + sheetInfo.width + "x" + sheetInfo.height);

  // Verify content: final sheet must have opaque pixels
  const sheetPngLoaded = await import("./lib/png-compositor.mjs").then(m => m.loadPngRgba(sheetPng));
  const opaquePixels = countOpaque(sheetPngLoaded.data);
  if (opaquePixels === 0) {
    console.error("FATAL: composed sheet is fully transparent — nothing was composited");
    process.exit(1);
  }
  console.log("Verification: " + opaquePixels + " opaque pixels in final sheet");

  // Collect credits
  const credits = collectCredits(def, assetIndex);
  const creditsPath = path.join(outputDir, "CREDITS.md");
  writeCredits(creditsPath, def.name, credits);
  console.log("Credits: " + credits.length + " entries written to " + creditsPath);

  // Generate report
  const duration = Date.now() - startTime;
  const report = generateReport({
    characterName: def.name,
    bodyType: def.bodyType,
    animations: def.animations,
    itemCount: def.layers.length,
    totalImages: manifest.layers.reduce((s, l) => s + l.images.length, 0),
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

  // Publish if requested
  if (options.publish) {
    const publishDir = path.join(factoryRoot, "..", "..", "art", "sprites", "lpc");
    fs.mkdirSync(publishDir, { recursive: true });
    fs.copyFileSync(sheetPng, path.join(publishDir, def.name + ".png"));
    fs.copyFileSync(sheetJson, path.join(publishDir, def.name + ".json"));
    fs.copyFileSync(creditsPath, path.join(publishDir, def.name + "-CREDITS.md"));
    console.log("Published to:", publishDir);
  }

  return report;
}

function parseArgs(argv) {
  const args = argv.slice(2);
  const options = {};
  let definitionPath = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--output" || args[i] === "-o") {
      options.output = args[++i];
    } else if (args[i] === "--animations" || args[i] === "-a") {
      options.animations = args[++i];
    } else if (args[i] === "--publish") {
      options.publish = true;
    } else if (args[i] === "--help" || args[i] === "-h") {
      console.log("Usage: node scripts/build-character.mjs <definition.yaml> [--output <dir>] [--animations idle,walk] [--publish]");
      process.exit(0);
    } else if (!args[i].startsWith("-")) {
      definitionPath = args[i];
    }
  }
  if (!definitionPath) {
    console.error("Error: No definition file specified");
    process.exit(1);
  }
  return { definitionPath, options };
}

const { definitionPath, options } = parseArgs(process.argv);
buildCharacter(definitionPath, options).catch(err => {
  console.error("Fatal error:", err.message);
  process.exit(1);
});
