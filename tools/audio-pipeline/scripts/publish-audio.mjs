#!/usr/bin/env node
// publish-audio.mjs — copy approved, processed assets into the production
// audio/ tree and regenerate audio/audio-manifest.json (plan s36-s37, s40-s41).
//
// Gates:
//   * review.status must be "approved" (music ALWAYS; signature SFX flagged
//     approval in requirements.json too).
//   * every published file must already exist under processed/.
//   * license validation must pass for non-exempt assets.
import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import {
  META, PROCESSED, AUDIO_TREE,
  loadRegistry, loadRequirements,
  classifyLicense, categoryOf, outputStem, resolveProcessedExt, eventNumbering,
} from "./lib/common.mjs";

const dryRun = process.argv.includes("--dry-run");
const errors = [];

function main() {
  const reg = loadRegistry();
  const reqs = loadRequirements();
  const reqById = new Map();
  for (const group of ["music", "ambience", "sfx"]) {
    const section = reqs[group] ?? {};
    const entries = Array.isArray(section) ? section : Object.values(section).flat();
    for (const r of entries) reqById.set(r.id, r);
  }
  const signatureApproval = new Set(
    Object.values(reqById).filter((r) => r.review === "approval").map((r) => r.id)
  );

  const manifest = { version: 1, generatedAt: new Date().toISOString(), events: {} };
  let copied = 0;

  const numbering = eventNumbering(reg);
  for (const asset of reg.assets) {
    // License gate: prohibited/unknown licenses never publish.
    if (asset.policy !== "project-original") {
      const cls = classifyLicense(asset.license?.name);
      if (cls === "prohibited" || cls === "unknown" || cls === "tier3") {
        console.log(`gate ${asset.id}: license ${cls} — not published`);
        continue;
      }
    }

    // Review gate: music and signature events require explicit approval.
    const isMusic = asset.type === "music";
    const hasSignature = Object.keys(asset.events ?? {}).some((e) => signatureApproval.has(e));
    const needsApproval = isMusic || hasSignature || asset.review?.approvalRequired === true;
    if (asset.review?.status !== "approved") {
      console.log(`gate ${asset.id}: review.status=${asset.review?.status}${needsApproval ? " (approval required)" : ""} — not published`);
      continue;
    }

    for (const [eventId, mappings] of Object.entries(asset.events ?? {})) {
      const req = reqById.get(eventId);
      const dir = req?.dir ?? mappings[0]?.dir;
      const loop = req?.loop === true;
      if (!dir) {
        errors.push(`${asset.id}: no destination dir for ${eventId}`);
        continue;
      }
      const files = [];
      const destDir = AUDIO_TREE(dir);
      if (!dryRun) mkdirSync(destDir, { recursive: true });
      for (let i = 0; i < mappings.length; i++) {
        const seq = numbering.get(`${asset.id}|${eventId}|${i}`);
        const stem = outputStem(eventId, seq);
        const ext = resolveProcessedExt(asset.id, stem);
        if (!ext) {
          errors.push(`${asset.id}: processed file missing (${asset.id}/${stem}.ogg|.wav) — run npm run audio:normalize`);
          continue;
        }
        if (!dryRun) copyFileSync(PROCESSED(asset.id, stem + ext), path.join(destDir, stem + ext));
        files.push(`${dir}/${stem}${ext}`);
        copied += 1;
      }
      if (!files.length) continue;
      if (manifest.events[eventId]) {
        // Another approved asset already contributes to this event's variant
        // pool — merge (numbering guarantees unique filenames per event).
        const prev = manifest.events[eventId];
        prev.files.push(...files);
        if (prev.asset !== asset.id) {
          prev.contributors = [...new Set([...(prev.contributors ?? [prev.asset]), asset.id])];
        }
      } else {
        manifest.events[eventId] = {
          category: categoryOf(eventId),
          asset: asset.id,
          loop,
          review: req?.review ?? "standard",
          files,
        };
      }
    }
  }

  if (!dryRun) {
    writeFileSync(AUDIO_TREE("audio-manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
  }
  for (const e of errors) console.error(`ERROR: ${e}`);
  console.log(
    `publish${dryRun ? " (dry-run)" : ""}: ${copied} file(s), ${Object.keys(manifest.events).length} event(s) -> audio/audio-manifest.json`
  );
  process.exit(errors.length ? 1 : 0);
}

main();
