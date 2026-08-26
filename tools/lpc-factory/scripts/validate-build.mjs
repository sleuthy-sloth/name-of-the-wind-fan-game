// validate-build.mjs — Validate a built sprite sheet against its manifest
// and frame-data JSON. Checks:
//   - build/<name>/manifest.json parses; animations list non-empty
//   - sheet PNG loads, dimensions match JSON meta.size, has opaque pixels
//   - JSON frame rects are within bounds and sized to their animation frameSize
//   - every animation that resolved images in the manifest appears in the JSON
//   - CREDITS.md exists
// Usage:
//   node scripts/validate-build.mjs <name>            # validate build/<name>
//   node scripts/validate-build.mjs --all             # validate every build dir
//   node scripts/validate-build.mjs <name> --quiet    # only print failures

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

import { loadPngRgba, countOpaque } from "./lib/png-compositor.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const FACTORY_ROOT = path.resolve(__dirname, "..");
const BUILD_ROOT = path.join(FACTORY_ROOT, "build");

function validateBuildDir(buildName, quiet) {
  const problems = [];
  const dir = path.join(BUILD_ROOT, buildName);
  const fail = msg => problems.push(msg);

  if (!fs.existsSync(dir)) {
    fail("build directory missing: " + dir);
    return { name: buildName, valid: false, problems };
  }

  // manifest.json
  const manifestPath = path.join(dir, "manifest.json");
  let manifest = null;
  try {
    manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  } catch (e) {
    fail("manifest.json unreadable: " + e.message);
    return { name: buildName, valid: false, problems };
  }
  if (!Array.isArray(manifest.layers) || manifest.layers.length === 0) {
    fail("manifest has no animation layers");
  }
  const animsWithImages = (manifest.layers || [])
    .filter(l => Array.isArray(l.images) && l.images.length > 0)
    .map(l => l.animation);

  // Sheet PNG + JSON
  const sheetPng = path.join(dir, buildName + ".png");
  const sheetJson = path.join(dir, buildName + ".json");
  if (!fs.existsSync(sheetPng)) fail("sheet missing: " + sheetPng);
  if (!fs.existsSync(sheetJson)) fail("frame data missing: " + sheetJson);
  if (problems.length > 0) return { name: buildName, valid: false, problems };

  // PNG content checks
  let png;
  try {
    png = loadPngRgba(sheetPng);
  } catch (e) {
    fail("sheet PNG unparseable: " + e.message);
    return { name: buildName, valid: false, problems };
  }
  const opaque = countOpaque(png.data);
  if (opaque === 0) fail("sheet is fully transparent");

  // JSON content checks
  let data;
  try {
    data = JSON.parse(fs.readFileSync(sheetJson, "utf8"));
  } catch (e) {
    fail("frame data JSON unparseable: " + e.message);
    return { name: buildName, valid: false, problems };
  }

  const metaSize = data.meta && data.meta.size;
  if (!metaSize || metaSize.w !== png.width || metaSize.h !== png.height) {
    fail("meta.size " + JSON.stringify(metaSize) +
      " does not match PNG dimensions " + png.width + "x" + png.height);
  }

  const frames = data.frames || {};
  const frameKeys = Object.keys(frames);
  if (frameKeys.length === 0) fail("no frames in frame data");

  const seenAnims = new Set();
  for (const key of frameKeys) {
    const fr = frames[key].frame;
    if (!fr) { fail("frame " + key + ": missing rect"); continue; }
    if (fr.x < 0 || fr.y < 0 ||
        fr.x + fr.w > png.width || fr.y + fr.h > png.height) {
      fail("frame " + key + ": rect out of bounds " + JSON.stringify(fr));
    }
    const anim = key.replace(/_\d+_\d+$/, "");
    seenAnims.add(anim);
    const animMeta = data.meta && data.meta.animations && data.meta.animations[anim];
    if (!animMeta) {
      fail("frame " + key + ": no meta.animations entry for \"" + anim + "\"");
    } else if (fr.w !== animMeta.frameSize || fr.h !== animMeta.frameSize) {
      fail("frame " + key + ": size " + fr.w + "x" + fr.h +
        " != declared frameSize " + animMeta.frameSize);
    }
  }

  for (const anim of animsWithImages) {
    if (!seenAnims.has(anim)) {
      fail("manifest animation \"" + anim + "\" resolved images but is absent from frame data");
    }
  }

  if (!fs.existsSync(path.join(dir, "CREDITS.md"))) {
    fail("CREDITS.md missing");
  }

  const valid = problems.length === 0;
  if (!quiet || !valid) {
    console.log((valid ? "PASS" : "FAIL") + "  " + buildName +
      (valid ? "" : ""));
    if (!valid) problems.forEach(p => console.log("    - " + p));
  }
  return { name: buildName, valid, problems };
}

function listBuildDirs() {
  if (!fs.existsSync(BUILD_ROOT)) return [];
  return fs.readdirSync(BUILD_ROOT).filter(n => {
    const p = path.join(BUILD_ROOT, n);
    return fs.statSync(p).isDirectory() &&
      fs.existsSync(path.join(p, n + ".png"));
  });
}

function parseArgs(argv) {
  const args = argv.slice(2);
  const options = {};
  let target = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--all") options.all = true;
    else if (args[i] === "--quiet" || args[i] === "-q") options.quiet = true;
    else if (args[i] === "--help" || args[i] === "-h") {
      console.log("Usage: node scripts/validate-build.mjs <name>|--all [--quiet]");
      process.exit(0);
    } else if (!args[i].startsWith("-")) target = args[i];
  }
  return { target, options };
}

const { target, options } = parseArgs(process.argv);

let names;
if (options.all) {
  names = listBuildDirs();
  if (names.length === 0) {
    console.error("No builds found under " + BUILD_ROOT);
    process.exit(1);
  }
} else if (target) {
  names = [target];
} else {
  console.error("Error: specify a build name or --all");
  process.exit(1);
}

const results = names.map(n => validateBuildDir(n, options.quiet));
const failed = results.filter(r => !r.valid);
console.log("\nValidated " + results.length + " build(s): " +
  (results.length - failed.length) + " pass, " + failed.length + " fail");
process.exit(failed.length > 0 ? 1 : 0);
