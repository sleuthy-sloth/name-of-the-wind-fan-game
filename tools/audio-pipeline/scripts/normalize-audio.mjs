#!/usr/bin/env node
// normalize-audio.mjs — FFmpeg normalization into game-ready OGG (plan s29-s34).
// Never touches sources/original/; writes processed/<assetId>/<slug>_<NN>.ogg.
import { existsSync, mkdirSync, unlinkSync } from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import {
  SOURCES, PROCESSED, loadRegistry,
  hasFfmpeg, vorbisEncoder, outputStem, eventNumbering,
} from "./lib/common.mjs";

// Loudness targets per asset type (LUFS integrated, true peak dBTP).
const LOUDNESS = {
  music: { I: -20, TP: -2.0 },
  ambience: { I: -26, TP: -3.0 },
  sfx: { I: -14, TP: -1.5 },
};

// Quality ladder: the native vorbis encoder has content-specific bugs
// (floor_encode assertion), so retries at other qualities are tried first.
const Q_LADDER = [5, 4, 6];

const LOSSY_EXT = new Set([".mp3", ".m4a", ".aac", ".wma"]);

function codecArgs() {
  const enc = vorbisEncoder();
  if (enc === "libvorbis") return ["-c:a", "libvorbis"];
  // Native encoder: stereo-only and needs the experimental flag.
  if (enc === "vorbis") return ["-c:a", "vorbis", "-strict", "-2", "-ac", "2"];
  return null;
}

function parseArgs(argv) {
  const args = { all: false, force: false, id: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--all") args.all = true;
    else if (argv[i] === "--force") args.force = true;
    else if (argv[i] === "--id") args.id = argv[++i];
  }
  return args;
}

function runFfmpeg(src, dst, type, codec) {
  const target = LOUDNESS[type] ?? LOUDNESS.sfx;
  const filter = `loudnorm=I=${target.I}:TP=${target.TP}:LRA=11`;
  return spawnSync(
    "ffmpeg",
    [
      "-hide_banner", "-loglevel", "error", "-y",
      "-i", src,
      "-map_metadata", "-1",
      "-af", filter,
      "-ar", "44100",
      ...codec,
      dst,
    ],
    { encoding: "utf8" }
  );
}

function encode(src, dstBase, type, codec) {
  const oggDst = `${dstBase}.ogg`;
  for (const q of Q_LADDER) {
    // A crashed encoder leaves a partial/corrupt file — start clean, clean after.
    if (existsSync(oggDst)) unlinkSync(oggDst);
    const res = runFfmpeg(src, oggDst, type, [...codec, "-q:a", String(q)]);
    if (res.status === 0) return ".ogg";
    if (existsSync(oggDst)) unlinkSync(oggDst);
  }
  // WAV fallback — acceptable for very short latency-sensitive samples
  // (plan s30). Still loudness-normalized via sample_format-safe filter.
  const target = LOUDNESS[type] ?? LOUDNESS.sfx;
  const res = spawnSync(
    "ffmpeg",
    [
      "-hide_banner", "-loglevel", "error", "-y",
      "-i", src,
      "-map_metadata", "-1",
      "-af", `loudnorm=I=${target.I}:TP=${target.TP}:LRA=11`,
      "-ar", "44100",
      "-c:a", "pcm_s16le",
      `${dstBase}.wav`,
    ],
    { encoding: "utf8" }
  );
  if (res.status === 0) return ".wav";
  return null;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!hasFfmpeg()) {
    console.error("FFmpeg not found on PATH. Install FFmpeg (e.g. `brew install ffmpeg`) and retry.");
    console.error("The pipeline refuses to process audio without it; no system packages were installed.");
    process.exit(2);
  }
  const codec = codecArgs();
  if (!codec) {
    console.error("No Vorbis encoder available in this FFmpeg build (need libvorbis or native vorbis).");
    process.exit(2);
  }

  const reg = loadRegistry();
  // Numbering is computed over the FULL registry so that multi-asset event
  // pools get stable, collision-free variant numbers even with --id filters.
  const numbering = eventNumbering(reg);
  let done = 0, skipped = 0, failed = 0;

  for (const asset of reg.assets) {
    if (args.id && asset.id !== args.id) continue;
    const outDir = PROCESSED(asset.id);
    const events = Object.entries(asset.events ?? {});
    if (!events.length) {
      console.log(`skip ${asset.id}: no event mappings`);
      continue;
    }
    for (const [eventId, mappings] of events) {
      for (let i = 0; i < mappings.length; i++) {
        const seq = numbering.get(`${asset.id}|${eventId}|${i}`);
        const rel = typeof mappings[i] === "string" ? mappings[i] : mappings[i].file;
        const src = SOURCES("original", rel);
        if (!existsSync(src)) {
          console.error(`ERROR ${asset.id}: missing original ${rel}`);
          failed += 1;
          continue;
        }
        const fname = outputStem(eventId, seq);
        const dstBase = path.join(outDir, fname);
        if (!args.force && existsSync(`${dstBase}.ogg`)) {
          skipped += 1;
          continue;
        }
        if (!args.force && existsSync(`${dstBase}.wav`)) {
          skipped += 1;
          continue;
        }
        const ext = path.extname(rel).toLowerCase();
        if (LOSSY_EXT.has(ext)) {
          console.warn(`WARN ${asset.id}/${rel}: lossy source (${ext}); prefer WAV/FLAC originals when available`);
        }
        mkdirSync(outDir, { recursive: true });
        // Remove stale outputs of the other extension before re-encoding.
        for (const stale of [".ogg", ".wav"]) {
          if (existsSync(dstBase + stale) && existsSync(dstBase + (stale === ".ogg" ? ".wav" : ".ogg"))) {
            // keep whichever encode() produces; cleanup happens below on success
          }
        }
        const produced = encode(src, dstBase, asset.type ?? "sfx", codec);
        if (!produced) {
          console.error(`ERROR encoding failed for ${rel} (ogg ladder + wav fallback)`);
          failed += 1;
        } else {
          const other = produced === ".ogg" ? ".wav" : ".ogg";
          if (existsSync(dstBase + other)) unlinkSync(dstBase + other);
          console.log(`ok ${path.join(asset.id, fname + produced)} <- ${rel}`);
          done += 1;
        }
      }
    }
  }

  console.log(`normalize: ${done} encoded, ${skipped} up-to-date, ${failed} failed`);
  process.exit(failed ? 1 : 0);
}

main();
