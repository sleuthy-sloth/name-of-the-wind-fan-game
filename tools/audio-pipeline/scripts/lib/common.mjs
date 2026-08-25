// Shared helpers for the audio pipeline.
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

// common.mjs lives at <root>/scripts/lib/, so the pipeline root is three levels up.
export const ROOT =
  process.env.AUDIO_PIPELINE_ROOT ?? path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
export const META = (...p) => path.join(ROOT, "metadata", ...p);
export const SOURCES = (...p) => path.join(ROOT, "sources", ...p);
export const PROCESSED = (...p) => path.join(ROOT, "processed", ...p);
export const CANDIDATES = (...p) => path.join(ROOT, "candidates", ...p);
// Production audio tree lives at the repository root (repo keeps top-level
// category dirs: art/, audio/, maps/, data/).
export const REPO = (...p) => path.resolve(ROOT, "..", "..", ...p);
export const AUDIO_TREE = (...p) => REPO("audio", ...p);
export const CREDITS_DIR = (...p) => REPO("CREDITS", ...p);

export function readJson(file) {
  return JSON.parse(readFileSync(file, "utf8"));
}

export function writeJson(file, value) {
  mkdirSync(path.dirname(file), { recursive: true });
  writeFileSync(file, JSON.stringify(value, null, 2) + "\n");
}

export function loadRegistry() {
  const file = META("licenses.json");
  if (!existsSync(file)) throw new Error(`missing registry: ${file}`);
  const reg = readJson(file);
  if (!Array.isArray(reg.assets)) throw new Error("licenses.json must contain an assets array");
  return reg;
}

export function saveRegistry(reg) {
  reg.assets.sort((a, b) => a.id.localeCompare(b.id));
  writeJson(META("licenses.json"), reg);
}

export function loadRequirements() {
  const file = META("requirements.json");
  if (!existsSync(file)) throw new Error(`missing requirements: ${file}`);
  return readJson(file);
}

// ---------------------------------------------------------------------------
// License policy (plan sections 1-4, 43)
// ---------------------------------------------------------------------------

/**
 * Classify a license name string.
 * @returns {"tier1"|"tier2"|"tier3"|"prohibited"|"unknown"}
 */
export function classifyLicense(name) {
  if (!name || typeof name !== "string") return "unknown";
  const upper = name.trim().toUpperCase();
  if (!upper) return "unknown";
  if (/CC0|PUBLIC DOMAIN/.test(upper)) {
    // "CC0 + NC" style combos stay prohibited even though CC0 appears.
    return /\bNC\b|\bND\b|NON[- ]?COMMERCIAL/.test(upper.replace(/CC0/g, "")) ? "prohibited" : "tier1";
  }
  if (/\bNC\b|\bND\b|NON[- ]?COMMERCIAL|NO[- ]DERIV|PERSONAL USE/.test(upper)) return "prohibited";
  if (/PIXABAY CONTENT LICENSE/.test(upper)) return "tier1";
  if (/^CC( |-)?BY( |-)?(4\.0|3\.0|2\.5|2\.0)?$/.test(upper)) return "tier2";
  if (/CC( |-)?BY( |-)?SA|OGA-BY|\bGPL\b/.test(upper)) return "tier3";
  // "royalty free"/"free to use" claims are NOT licenses (plan s43): unknown.
  return "unknown";
}

/** Evidence fields required before an attribution-bearing asset publishes. */
export function missingAttribution(asset) {
  const src = asset.source ?? {};
  const gaps = [];
  if (!src.creator) gaps.push("source.creator");
  if (!src.url) gaps.push("source.url");
  if (!asset.license?.url && asset.license?.name?.toUpperCase().includes("BY")) gaps.push("license.url");
  if (!src.downloadDate) gaps.push("source.downloadDate");
  return gaps;
}

// ---------------------------------------------------------------------------
// Logical IDs (plan section 35-36): UPPER_SNAKE, prefix MUS_/AMB_/SFX_
// ---------------------------------------------------------------------------

const ID_RE = /^(MUS|AMB|SFX|INSTR)_[A-Z0-9]+(_[A-Z0-9]+)*$/;

export function isValidLogicalId(id) {
  return typeof id === "string" && ID_RE.test(id);
}

/**
 * Deterministic variant numbering across ALL assets contributing to an event:
 * assets iterate in registry order; each mapping takes the next free number.
 * Every script (index/normalize/publish/credits) computes this identically so
 * processed/, audio/ and credits always agree even when several sources feed
 * one logical event's variant pool.
 *
 * @returns {Map<string,number>} key `"assetId|eventId|mappingIdx"` -> 1-based seq
 */
export function eventNumbering(reg) {
  const counters = new Map();
  const out = new Map();
  for (const asset of reg.assets) {
    for (const [eventId, mappings] of Object.entries(asset.events ?? {})) {
      for (let i = 0; i < mappings.length; i++) {
        const n = (counters.get(eventId) ?? 0) + 1;
        counters.set(eventId, n);
        out.set(`${asset.id}|${eventId}|${i}`, n);
      }
    }
  }
  return out;
}

/**
 * Ship-ready filename stem for a logical event id + variant number:
 *   SFX_FOOT_STONE   v1 -> "foot_stone_01"
 *   SFX_PAGE_TURN_02 v1 -> "page_turn_02"   (event carries its own number)
 *   AMB_TARBEAN_NIGHT v1 -> "tarbean_night_01"
 * Extension is chosen by normalize (".ogg", or ".wav" when Vorbis fails).
 */
export function outputStem(id, seq /* 1-based */) {
  const base = id.toLowerCase().replace(/^(sfx|amb|mus|instr)_/, "");
  if (/_(\d+)$/.test(base)) return base;
  return `${base}_${String(seq).padStart(2, "0")}`;
}

/** Production subdirectory for a logical id (falls back to the asset dir). */
export function categoryOf(id) {
  if (id.startsWith("MUS_")) return "music";
  if (id.startsWith("AMB_")) return "ambience";
  if (id.startsWith("INSTR_")) return "instruments";
  return "sfx";
}

/** Resolve which processed extension exists for a stem (".ogg" or ".wav"). */
export function resolveProcessedExt(assetId, stem) {
  const base = PROCESSED(assetId, stem);
  if (existsSync(`${base}.ogg`)) return ".ogg";
  if (existsSync(`${base}.wav`)) return ".wav";
  return null;
}

// ---------------------------------------------------------------------------
// External tools
// ---------------------------------------------------------------------------

let _ffmpegCache;

export function hasFfmpeg() {
  if (_ffmpegCache !== undefined) return _ffmpegCache;
  try {
    const res = spawnSync("ffmpeg", ["-version"], { encoding: "utf8" });
    _ffmpegCache = res.status === 0 && /ffmpeg version/i.test(res.stdout ?? "");
  } catch {
    _ffmpegCache = false;
  }
  return _ffmpegCache;
}

/**
 * Best available Vorbis encoder. Homebrew FFmpeg builds often lack libvorbis
 * but ship the native encoder (stereo-only). Returns null when neither exists.
 * @returns {"libvorbis"|"vorbis"|null}
 */
export function vorbisEncoder() {
  try {
    const res = spawnSync("ffmpeg", ["-hide_banner", "-encoders"], { encoding: "utf8" });
    const out = res.stdout ?? "";
    if (/\slibvorbis\s/.test(out)) return "libvorbis";
    if (/\svorbis\s/.test(out)) return "vorbis";
  } catch {
    /* fall through */
  }
  return null;
}
