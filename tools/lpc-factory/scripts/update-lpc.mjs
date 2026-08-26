// update-lpc.mjs — Sync the vendored upstream LPC clone to the pinned commit.
// The pin is the `upstreamCommit` recorded in metadata/asset-index.json (the
// commit inspect-lpc last indexed). After changing the pin or pulling new
// upstream content, rerun `node scripts/inspect-lpc.mjs` before any build.
//
// Usage:
//   node scripts/update-lpc.mjs            # clone if missing, fetch + checkout pin
//   node scripts/update-lpc.mjs --check    # report only, no mutation
//   node scripts/update-lpc.mjs --pin <sha|branch|tag>
//   node scripts/update-lpc.mjs --main     # checkout origin/main (then re-inspect!)

import { execFileSync } from "child_process";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const FACTORY_ROOT = path.resolve(__dirname, "..");
const UPSTREAM_DIR = path.join(FACTORY_ROOT, "upstream", "universal-lpc");
const REMOTE = "https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator.git";

function git(cwd, ...args) {
  return execFileSync("git", args, { cwd, encoding: "utf8" }).trim();
}

function currentHead() {
  try {
    return git(UPSTREAM_DIR, "rev-parse", "HEAD");
  } catch {
    return null;
  }
}

function isDirty() {
  try {
    return git(UPSTREAM_DIR, "status", "--porcelain").length > 0;
  } catch {
    return false;
  }
}

function parseArgs(argv) {
  const args = argv.slice(2);
  const options = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--check") options.check = true;
    else if (args[i] === "--pin") options.pin = args[++i];
    else if (args[i] === "--main") options.pin = "origin/main";
    else if (args[i] === "--help" || args[i] === "-h") {
      console.log("Usage: node scripts/update-lpc.mjs [--check] [--pin <ref>] [--main]");
      process.exit(0);
    }
  }
  return options;
}

const options = parseArgs(process.argv);

// Resolve the target pin: explicit flag wins, else the indexed commit
let pin;
if (options.pin) {
  pin = options.pin;
  console.log("Pin source: command line (" + pin + ")");
} else {
  const indexPath = path.join(FACTORY_ROOT, "metadata", "asset-index.json");
  if (!fs.existsSync(indexPath)) {
    console.error("No asset-index.json and no --pin given. Run inspect-lpc.mjs or pass --pin.");
    process.exit(1);
  }
  pin = JSON.parse(fs.readFileSync(indexPath, "utf8")).upstreamCommit;
  console.log("Pin source: metadata/asset-index.json (" + pin.slice(0, 12) + ")");
}

const exists = fs.existsSync(path.join(UPSTREAM_DIR, ".git"));
if (!exists) {
  if (options.check) {
    console.log("CHECK: upstream clone missing at " + UPSTREAM_DIR);
    process.exit(1);
  }
  console.log("Cloning upstream into " + path.relative(FACTORY_ROOT, UPSTREAM_DIR) + " ...");
  fs.mkdirSync(path.dirname(UPSTREAM_DIR), { recursive: true });
  execFileSync("git", ["clone", "--quiet", REMOTE, UPSTREAM_DIR], { stdio: "inherit" });
} else if (!options.check) {
  console.log("Fetching upstream updates...");
  execFileSync("git", ["fetch", "--quiet", "origin"], { cwd: UPSTREAM_DIR, stdio: "inherit" });
}

const head = currentHead();
console.log("Upstream HEAD: " + (head ? head.slice(0, 12) : "(none)"));

if (head === pin || (head && head.startsWith(pin))) {
  console.log("Already at pinned revision.");
} else if (isDirty()) {
  console.error("REFUSING: upstream working tree has local modifications. " +
    "Resolve them first (never commit inside upstream/universal-lpc).");
  process.exit(1);
} else if (options.check) {
  console.log("CHECK FAIL: upstream HEAD " +
    (head ? head.slice(0, 12) : "(missing)") + " != pinned " + pin.slice(0, 12));
  process.exit(1);
} else {
  console.log("Checking out " + pin.slice(0, 12) + " ...");
  git(UPSTREAM_DIR, "checkout", "--quiet", pin);
  console.log("Now at: " + currentHead().slice(0, 12));
}

if (options.check) {
  console.log("CHECK PASS: upstream matches pin " + pin.slice(0, 12));
}
console.log("\nNext step: if the pin changed, rerun `node scripts/inspect-lpc.mjs` " +
  "to regenerate the indexes before any build.");
