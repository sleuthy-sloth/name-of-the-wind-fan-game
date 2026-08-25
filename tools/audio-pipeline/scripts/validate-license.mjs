#!/usr/bin/env node
// validate-license.mjs — enforce the licensing policy (plan s1-s4, s43).
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import {
  SOURCES, loadRegistry,
  classifyLicense, missingAttribution,
} from "./lib/common.mjs";

const violations = [];
const rows = [];

function main() {
  const reg = loadRegistry();
  for (const asset of reg.assets) {
    if (asset.policy === "project-original") {
      rows.push({ id: asset.id, license: "project-original", tier: "exempt", note: "self-authored under LICENSE-ASSETS.md" });
      continue;
    }
    const cls = classifyLicense(asset.license?.name);
    const evidenceFile = SOURCES("licenses", `${asset.id}.json`);
    let evidenceOk = existsSync(evidenceFile);
    let evidenceNote = "";
    if (evidenceOk) {
      try {
        const ev = JSON.parse(readFileSync(evidenceFile, "utf8"));
        for (const field of ["site", "creator", "title", "url", "downloadDate"]) {
          if (!ev.source?.[field]) {
            evidenceOk = false;
            evidenceNote += ` evidence.${field}`;
          }
        }
        if (!ev.license?.name) {
          evidenceOk = false;
          evidenceNote += " evidence.license";
        }
      } catch (err) {
        evidenceOk = false;
        evidenceNote = ` unreadable (${err.message})`;
      }
    } else {
      evidenceNote = " missing file";
    }

    const gaps = missingAttribution(asset);
    switch (cls) {
      case "tier1":
        break;
      case "tier2":
        if (gaps.length) violations.push(`${asset.id}: CC-BY attribution incomplete — missing ${gaps.join(", ")}`);
        break;
      case "tier3":
        // Review-required bucket only; publish gate refuses these.
        rows.push({ id: asset.id, license: asset.license?.name, tier: cls, note: "REVIEW REQUIRED — never auto-publish" });
        continue;
      case "prohibited":
        violations.push(`${asset.id}: PROHIBITED license "${asset.license?.name}"`);
        break;
      default:
        violations.push(`${asset.id}: LICENSE UNKNOWN "${asset.license?.name ?? "(none)"}" — reject until terms are confirmed`);
    }

    if (!evidenceOk) violations.push(`${asset.id}: license evidence invalid${evidenceNote}`);
    rows.push({
      id: asset.id,
      license: asset.license?.name,
      tier: cls,
      attribution: asset.license?.attributionRequired ? "required" : "none",
      evidence: evidenceOk ? "ok" : `BAD${evidenceNote}`,
    });
  }

  console.log("id | license | tier | attribution | evidence");
  for (const r of rows) console.log([r.id, r.license, r.tier, r.attribution ?? "-", r.evidence ?? "-"].join(" | "));
  for (const v of violations) console.error(`VIOLATION: ${v}`);
  console.log(`validate: ${rows.length} assets checked, ${violations.length} violation(s)`);
  process.exit(violations.length ? 1 : 0);
}

main();
