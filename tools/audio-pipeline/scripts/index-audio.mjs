#!/usr/bin/env node
// index-audio.mjs — validate the asset registry against files on disk and
// requirement coverage, then regenerate metadata/audio-index.json.
import { existsSync, readdirSync, statSync, readFileSync } from "node:fs";
import path from "node:path";
import {
  META, SOURCES, AUDIO_TREE,
  loadRegistry, loadRequirements, writeJson,
  isValidLogicalId, outputStem, eventNumbering,
} from "./lib/common.mjs";

const AUDIO_EXTS = new Set([".ogg", ".wav", ".flac", ".mp3", ".m4a"]);
const errors = [];
const warnings = [];

function walkAudioFiles(dir, baseDir = dir) {
  const found = [];
  if (!existsSync(dir)) return found;
  for (const entry of readdirSync(dir)) {
    const full = path.join(dir, entry);
    if (statSync(full).isDirectory()) {
      found.push(...walkAudioFiles(full, baseDir));
    } else if (AUDIO_EXTS.has(path.extname(entry).toLowerCase())) {
      found.push(path.relative(baseDir, full));
    }
  }
  return found;
}

function main() {
  const reg = loadRegistry();
  const numbering = eventNumbering(reg);
  const reqs = loadRequirements();
  const reqById = new Map();
  for (const group of ["music", "ambience", "sfx"]) {
    const section = reqs[group] ?? {};
    const entries = Array.isArray(section) ? section : Object.values(section).flat();
    for (const r of entries) {
      if (!isValidLogicalId(r.id)) errors.push(`requirement id malformed: ${r.id}`);
      if (reqById.has(r.id)) errors.push(`duplicate requirement id: ${r.id}`);
      reqById.set(r.id, r);
    }
  }

  const assets = [];
  const publishedByEvent = new Map(); // event -> [{file}]
  const coveredTargets = new Set();

  for (const asset of reg.assets) {
    const a = { id: asset.id, type: asset.type ?? "sfx", source: {}, license: {}, review: {}, events: {} };
    // --- provenance -------------------------------------------------------
    const src = asset.source ?? {};
    for (const field of ["site", "creator", "title", "url", "downloadDate"]) {
      if (!src[field]) errors.push(`${asset.id}: missing source.${field}`);
    }
    a.source = src;
    // --- license evidence -------------------------------------------------
    const lic = asset.license ?? {};
    if (!lic.name) errors.push(`${asset.id}: missing license.name`);
    if (asset.policy !== "project-original" && !lic.url) warnings.push(`${asset.id}: no license.url recorded`);
    a.license = lic;
    const evidence = SOURCES("licenses", `${asset.id}.json`);
    if (!existsSync(evidence)) errors.push(`${asset.id}: missing license evidence ${path.relative(process.cwd(), evidence)}`);
    // --- originals preserved ----------------------------------------------
    a.originalCount = 0;
    for (const rel of asset.original ?? []) {
      const p = SOURCES("original", rel);
      if (!existsSync(p)) errors.push(`${asset.id}: original file missing: ${rel}`);
      else a.originalCount += 1;
    }
    if (!(asset.original ?? []).length) warnings.push(`${asset.id}: no original files registered`);
    // --- review state ------------------------------------------------------
    const status = asset.review?.status;
    if (!["pending", "approved", "rejected"].includes(status)) {
      errors.push(`${asset.id}: review.status must be pending|approved|rejected (got ${status})`);
    }
    a.review = { status: status ?? null, reviewer: asset.review?.reviewer ?? null };
    // --- events ------------------------------------------------------------
    let variant = 0;
    for (const [eventId, mappings] of Object.entries(asset.events ?? {})) {
      if (!isValidLogicalId(eventId)) errors.push(`${asset.id}: bad logical id "${eventId}"`);
      if (!reqById.has(eventId)) warnings.push(`${asset.id}: event ${eventId} has no matching requirement`);
      const req = reqById.get(eventId);
      const dir = req?.dir ?? mappings[0]?.dir;
      if (!Array.isArray(mappings) || mappings.length === 0) {
        errors.push(`${asset.id}: event ${eventId} has no file mappings`);
        continue;
      }
      const files = [];
      for (let i = 0; i < mappings.length; i++) {
        const m = mappings[i];
        variant += 1;
        const rel = typeof m === "string" ? m : m.file;
        if (!existsSync(SOURCES("original", rel))) {
          errors.push(`${asset.id}: event ${eventId} original missing: ${rel}`);
          continue;
        }
        const seq = numbering.get(`${asset.id}|${eventId}|${i}`);
        const stem = outputStem(eventId, seq);
        const targetBase = path.join(dir ?? "", stem);
        // Either extension may end up published (vorbis failure -> wav).
        for (const ext of [".ogg", ".wav"]) {
          if (coveredTargets.has(targetBase + ext)) errors.push(`duplicate production target: ${targetBase + ext}`);
          coveredTargets.add(targetBase + ext);
        }
        files.push({ original: rel, processed: path.join(asset.id, stem), target: targetBase });
        publishedByEvent.set(eventId, [...(publishedByEvent.get(eventId) ?? []), path.join("audio", targetBase)]);
      }
      a.events[eventId] = { dir: dir ?? null, files };
    }

    assets.push(a);
  }

  // --- production tree audit ---------------------------------------------
  const tree = walkAudioFiles(AUDIO_TREE());
  const manifestPath = AUDIO_TREE("audio-manifest.json");
  if (existsSync(manifestPath)) {
    try {
      JSON.parse(readFileSync(manifestPath, "utf8"));
    } catch {
      warnings.push("existing audio-manifest.json is not valid JSON (run publish-audio.mjs)");
    }
  } else {
    warnings.push("no audio-manifest.json yet (run npm run audio:publish)");
  }
  const orphans = tree.filter((f) => !coveredTargets.has(f));

  const coverage = [];
  for (const [id, req] of reqById) {
    const have = (publishedByEvent.get(id) ?? []).length;
    const min = req.variants?.min ?? 1;
    coverage.push({
      id, dir: req.dir, min,
      status: have >= min ? "filled" : have > 0 ? "partial" : "unfilled",
      variants: have,
      priority: req.priority ?? null,
    });
  }

  const index = {
    generatedAt: new Date().toISOString(),
    totals: {
      requirements: reqById.size,
      filled: coverage.filter((c) => c.status === "filled").length,
      partial: coverage.filter((c) => c.status === "partial").length,
      unfilled: coverage.filter((c) => c.status === "unfilled").length,
      assets: reg.assets.length,
      productionFiles: tree.length,
    },
    verticalSlice: coverage.filter((c) => c.priority === "vertical-slice"),
    coverage,
    assets,
    productionOrphans: orphans,
  };
  writeJson(META("audio-index.json"), index);

  for (const w of warnings) console.warn(`WARN: ${w}`);
  for (const e of errors) console.error(`ERROR: ${e}`);
  console.log(
    `index: ${index.totals.assets} assets, ${index.totals.requirements} requirements ` +
      `(filled ${index.totals.filled}, partial ${index.totals.partial}, unfilled ${index.totals.unfilled}), ` +
      `${tree.length} production files, ${orphans.length} orphan(s)`
  );
  process.exit(errors.length ? 1 : 0);
}

main();
