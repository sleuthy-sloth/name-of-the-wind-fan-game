import { readFileSync, writeFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, basename, relative } from "node:path";
import { execSync } from "node:child_process";

const ROOT = join(import.meta.dirname, "..");
const UPSTREAM = join(ROOT, "upstream/universal-lpc");
const SHEET_DEF = join(UPSTREAM, "sheet_definitions");
const SPRITES = join(UPSTREAM, "spritesheets");
const META = join(ROOT, "metadata");

const FRAME_SIZE = 64;
const DIRECTIONS = ["up", "left", "down", "right"];
const BODY_TYPES = ["male", "female", "teen", "child", "muscular", "pregnant"];
const ANIM_OFFSETS = { spellcast: 0, thrust: 4, walk: 8, slash: 12, shoot: 16, hurt: 20, climb: 21, idle: 22, jump: 26, sit: 30, emote: 34, run: 38, combat_idle: 42, backslash: 46, halfslash: 50 };
const ANIM_FOLDER = { combat: "combat_idle", "1h_slash": "backslash", "1h_backslash": "backslash", "1h_halfslash": "halfslash" };
const ANIM_DEFAULTS = ["spellcast", "thrust", "walk", "slash", "shoot", "hurt", "watering"];
const DIR_TYPE = { arms: "arms", body: "body", feet: "feet", hair: "hair", head: "head", headwear: "headwear", legs: "legs", tools: "tools", torso: "torso", weapons: "weapon" };

function walk(dir) {
  let out = [];
  for (const e of readdirSync(dir)) {
    const f = join(dir, e);
    const st = statSync(f);
    if (st.isDirectory()) out = out.concat(walk(f));
    else if (e.endsWith(".json") && !e.startsWith("meta_")) out.push(f);
  }
  return out;
}

function slug(s) { return s.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, ""); }
function resolveAnimFolder(a) { return ANIM_FOLDER[a] || a; }
function getCommit() { try { return execSync("git rev-parse HEAD", { cwd: UPSTREAM }).toString().trim(); } catch (e) { return "unknown"; } }

function checkSprite(basePath, anim) {
  const folder = resolveAnimFolder(anim);
  const dir = join(SPRITES, basePath);
  if (!existsSync(dir)) return { exists: false, type: "no-dir", files: [] };
  const flat = join(dir, folder + ".png");
  if (existsSync(flat)) return { exists: true, type: "flat", file: folder + ".png" };
  const animDir = join(dir, folder);
  if (existsSync(animDir) && statSync(animDir).isDirectory()) {
    const files = readdirSync(animDir).filter(f => f.endsWith(".png"));
    if (files.length > 0) return { exists: true, type: "variant-dir", files };
  }
  const variants = readdirSync(dir).filter(f => f.endsWith(".png"));
  if (variants.length > 0) return { exists: true, type: "full-sheet", files: variants };
  return { exists: false, type: "no-files", files: [] };
}

const files = walk(SHEET_DEF);
console.log("Found " + files.length + " sheet definition files");
const items = {};
const animIndex = {};
const licIndex = {};
const collisions = {};

for (const f of files) {
  let data;
  try { data = JSON.parse(readFileSync(f, "utf8")); } catch (e) { console.error("WARN: parse " + f + ": " + e.message); continue; }
  if (!data.name) continue;
  let typeName = data.type_name;
  if (!typeName) { const rel = relative(SHEET_DEF, f); typeName = DIR_TYPE[rel.split("/")[0]] || rel.split("/")[0]; }
  let id = typeName + "." + slug(data.name);
  if (items[id]) { collisions[id] = (collisions[id] || 1) + 1; id = typeName + "." + slug(basename(f, ".json")); }
  const layers = {};
  for (let i = 1; i <= 9; i++) {
    const lk = "layer_" + i;
    if (!data[lk]) break;
    const layer = { zPos: data[lk].zPos || 100, paths: {} };
    for (const bt of BODY_TYPES) { if (data[lk][bt]) layer.paths[bt] = data[lk][bt]; }
    if (data[lk].custom_animation) layer.customAnimation = data[lk].custom_animation;
    layers[lk] = layer;
  }
  const animations = data.animations || ANIM_DEFAULTS;
  const credits = data.credits || [];
  const variants = data.variants || [];
  const recolors = data.recolors || null;
  const availability = {};
  for (const bt of BODY_TYPES) {
    const l1 = layers.layer_1;
    if (!l1 || !l1.paths[bt]) { availability[bt] = null; continue; }
    availability[bt] = {};
    for (const anim of animations) availability[bt][anim] = checkSprite(l1.paths[bt], anim);
  }
  items[id] = { id, name: data.name, type: typeName, sourceFile: relative(SHEET_DEF, f), layers, animations, variants, recolors, credits, availability, matchBodyColor: data.match_body_color || false, priority: data.priority || 100 };
  for (const anim of animations) { if (!animIndex[anim]) animIndex[anim] = []; animIndex[anim].push(id); }
  for (const c of credits) for (const lic of (c.licenses || [])) {
    if (!licIndex[lic]) licIndex[lic] = { authors: new Set(), items: [] };
    for (const a of (c.authors || [])) licIndex[lic].authors.add(a);
    if (!licIndex[lic].items.includes(id)) licIndex[lic].items.push(id);
  }
}

const licOut = {};
for (const [k, v] of Object.entries(licIndex)) licOut[k] = { authors: [...v.authors], items: v.items };
const commit = getCommit();
const ts = new Date().toISOString();
writeFileSync(join(META, "asset-index.json"), JSON.stringify({ generatedAt: ts, upstreamCommit: commit, frameSize: FRAME_SIZE, bodyTypes: BODY_TYPES, directions: DIRECTIONS, animationOffsets: ANIM_OFFSETS, itemCount: Object.keys(items).length, catalog: items }, null, 2));
writeFileSync(join(META, "animation-index.json"), JSON.stringify({ generatedAt: ts, upstreamCommit: commit, animations: animIndex }, null, 2));
writeFileSync(join(META, "license-index.json"), JSON.stringify({ generatedAt: ts, upstreamCommit: commit, licenses: licOut }, null, 2));
console.log("Indexed " + Object.keys(items).length + " items");
console.log("Animations: " + Object.keys(animIndex).sort().join(", "));
console.log("Licenses: " + Object.keys(licOut).join(", "));
console.log("Types: " + [...new Set(Object.values(items).map(i => i.type))].sort().join(", "));
if (Object.keys(collisions).length > 0) console.log("ID collisions: " + JSON.stringify(collisions));
console.log("Wrote metadata/asset-index.json, animation-index.json, license-index.json");
