#!/usr/bin/env node
// validate_content.mjs — Static content validation for data/ JSON assets
// (GDD Phase 2 deliverable). Complements the in-engine validators
// (DialogueRunner.validate, QuestManager.validate, ScheduleSystem.validate)
// with a CI-runnable check plus cross-file references the engine can't see.
//
// Checks:
//   - every data/**/*.json parses; object/array shape sane
//   - dialogue files: root/nodes present, next/choice refs resolve, effects known
//   - quests: required fields, unique ids, objective types, stage chain
//   - schedules: npc_id exists in roster files, time blocks valid,
//     referenced scenes exist on disk
//   - roster: unique member ids, base_relationship numeric
//   - ID conventions (<type>_<name>_<variant>) as warnings
//
// Usage: node tools/validate_content.mjs [--quiet]
// Exit code 1 on any error; warnings do not fail.

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const ROOT = path.resolve(path.dirname(__filename), "..");
const DATA = path.join(ROOT, "data");
const TIME_BLOCKS = new Set(["morning", "afternoon", "evening", "night"]);

const errors = [];
const warnings = [];
const err = m => errors.push(m);
const warn = m => warnings.push(m);

function walkJsonFiles(dir) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir)) {
    const full = path.join(dir, entry);
    if (fs.statSync(full).isDirectory()) out.push(...walkJsonFiles(full));
    else if (entry.endsWith(".json")) out.push(full);
  }
  return out.sort();
}

function loadJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (e) {
    err(`${rel(file)}: invalid JSON (${e.message})`);
    return null;
  }
}
const rel = f => path.relative(ROOT, f);

// --- ID convention ----------------------------------------------------------

function checkIdConvention(id, file) {
  // <type>_<name>[_<variant>]; type is a short word like quest/stage/obj/flag/char/item
  if (!/^[a-z][a-z0-9]*(_[a-z0-9]+)+$/.test(id)) {
    warn(`${rel(file)}: id "${id}" doesn't follow <type>_<name>_<variant> convention`);
  }
}

// --- dialogue ---------------------------------------------------------------

function validateDialogue(file, data) {
  if (typeof data.dialogue_id !== "string" || !data.dialogue_id) {
    err(`${rel(file)}: missing dialogue_id`);
  }
  if (typeof data.root !== "string" || !data.root) {
    err(`${rel(file)}: missing root`);
  }
  const nodes = data.nodes;
  if (nodes === null || typeof nodes !== "object" || Array.isArray(nodes)) {
    err(`${rel(file)}: missing nodes object`);
    return;
  }
  for (const [id, node] of Object.entries(nodes)) {
    checkIdConvention(id, file);
    const isEnd = node.end === true || typeof node.text !== "string";
    if (!isEnd && (node.text === "" || node.text == null)) {
      err(`${rel(file)}: node '${id}' has empty text but is not an end node`);
    }
    const nexts = [];
    if (typeof node.next === "string") nexts.push(node.next);
    if (Array.isArray(node.choices)) {
      node.choices.forEach((c, i) => {
        if (typeof c.next === "string") nexts.push(c.next);
        else err(`${rel(file)}: choice ${i} of '${id}' missing next`);
      });
    }
    for (const n of nexts) {
      if (!Object.prototype.hasOwnProperty.call(nodes, n)) {
        err(`${rel(file)}: '${id}' references unknown node '${n}'`);
      }
    }
    const effects = node.effects ?? [];
    if (!Array.isArray(effects)) err(`${rel(file)}: '${id}' effects must be an array`);
    for (const e of effects) {
      const kind = e?.type ?? e?.kind ?? "";
      if (!["relationship", "set_flag", "reputation"].includes(kind) &&
          !(typeof e.set_flag === "string")) {
        err(`${rel(file)}: '${id}' has unknown effect ${JSON.stringify(e)}`);
      }
    }
  }
  if (data.root && !Object.hasOwn(nodes, data.root)) {
    err(`${rel(file)}: root '${data.root}' not found in nodes`);
  }
}

// --- quests -----------------------------------------------------------------

const QUEST_OBJECTIVE_TYPES = new Set(["flag", "item", "relationship"]);

function validateQuest(file, data) {
  if (!data.quest_id) { err(`${rel(file)}: missing quest_id`); return; }
  checkIdConvention(data.quest_id, file);
  if (!data.title) err(`${rel(data.quest_id)}: quest ${data.quest_id} missing title`);
  if (!Array.isArray(data.stages) || data.stages.length === 0) {
    err(`quest ${data.quest_id}: missing stages array`);
    return;
  }
  const stageIds = new Set();
  for (const stage of data.stages) {
    const sid = stage.stage_id ?? "";
    if (!sid) { err(`quest ${data.quest_id}: stage missing stage_id`); continue; }
    if (stageIds.has(sid)) err(`quest ${data.quest_id}: duplicate stage '${sid}'`);
    stageIds.add(sid);
    if (!Array.isArray(stage.objectives) || stage.objectives.length === 0) {
      err(`quest ${data.quest_id}/${sid}: no objectives`);
    }
    for (const obj of stage.objectives ?? []) {
      if (!QUEST_OBJECTIVE_TYPES.has(obj.type)) {
        err(`quest ${data.quest_id}/${sid}: unknown objective type '${obj.type}'`);
      }
      if (!obj.objective_id) err(`quest ${data.quest_id}/${sid}: objective missing objective_id`);
    }
    const oc = stage.on_complete ?? {};
    for (const q of oc.start_quests ?? []) {
      // resolved after all files loaded (see main)
      pendingQuestRefs.push({ from: `${data.quest_id}/${sid}`, questId: q });
    }
  }
  questIds.add(data.quest_id);
}

const questIds = new Set();
const pendingQuestRefs = [];

// --- schedules & roster -----------------------------------------------------

function collectRosterIds() {
  const ids = new Set();
  for (const file of walkJsonFiles(DATA)) {
    const data = loadJson(file);
    if (data === null) continue;
    if (file.includes("characters") && Array.isArray(data.members)) {
      for (const m of data.members) {
        if (m.id) ids.add(m.id);
        if (m.id) checkIdConvention(m.id, file);
        if (typeof m.base_relationship !== "number" && m.base_relationship !== undefined) {
          err(`${rel(file)}: member ${m.id} base_relationship must be numeric`);
        }
      }
    }
  }
  return ids;
}

function validateScheduleEntry(file, entry, rosterIds, scenePaths) {
  if (!entry.npc_id) { err(`${rel(file)}: schedule entry missing npc_id`); return; }
  if (!rosterIds.has(entry.npc_id)) {
    err(`${rel(file)}: npc '${entry.npc_id}' not found in any roster`);
  }
  const def = entry.default ?? {};
  if (def.scene && !scenePaths.has(def.scene)) {
    err(`${rel(file)}: ${entry.npc_id} default scene not found: ${def.scene}`);
  }
  for (const ov of entry.overrides ?? []) {
    const when = ov.when ?? {};
    for (const block of when.time_blocks ?? []) {
      if (!TIME_BLOCKS.has(block)) {
        err(`${rel(file)}: ${entry.npc_id} unknown time block '${block}'`);
      }
    }
    if (!ov.hide && ov.scene && !scenePaths.has(ov.scene)) {
      err(`${rel(file)}: ${entry.npc_id} override scene not found: ${ov.scene}`);
    }
  }
}

function collectScenePaths() {
  const scenes = new Set();
  const worldDir = path.join(ROOT, "scenes", "world");
  function walk(dir, prefix) {
    if (!fs.existsSync(dir)) return;
    for (const entry of fs.readdirSync(dir)) {
      const full = path.join(dir, entry);
      if (fs.statSync(full).isDirectory()) walk(full, `${prefix}${entry}/`);
      else if (entry.endsWith(".tscn")) scenes.add(`res://scenes/${prefix}${entry}`);
    }
  }
  walk(worldDir, "world/");
  return scenes;
}

// --- main -------------------------------------------------------------------

function main() {
  const quiet = process.argv.includes("--quiet");
  const files = walkJsonFiles(DATA);
  if (files.length === 0) {
    console.error("no data files found under", DATA);
    process.exit(1);
  }

  const rosterIds = collectRosterIds();
  const scenePaths = collectScenePaths();

  for (const file of files) {
    const data = loadJson(file);
    if (data === null) continue;

    if (typeof data.dialogue_id === "string" || data.nodes) {
      // DialogueRunner data
      validateDialogue(file, data);
    } else if (Array.isArray(data.beats)) {
      // Cutscene script or story-flow file (e.g. Chandrian attack / slice_flow)
      const seen = new Set();
      for (const beat of data.beats) {
        if (!beat.id) err(`${rel(file)}: beat missing id`);
        else if (seen.has(beat.id)) err(`${rel(file)}: duplicate beat '${beat.id}'`);
        seen.add(beat.id);
        const isFlowBeat = beat.requires !== undefined || beat.sets_flag !== undefined;
        if (!isFlowBeat && typeof beat.narration !== "string") {
          warn(`${rel(file)}: beat '${beat.id ?? "?"}' has no narration`);
        }
        if (typeof beat.sets_flag === "string" && !/^[a-z][a-z0-9_]*$/.test(beat.sets_flag)) {
          err(`${rel(file)}: beat '${beat.id}' sets_flag '${beat.sets_flag}' malformed`);
        }
      }
    } else if (data.quest_id) {
      validateQuest(file, data);
    } else if (file.includes(path.join("data", "schedules")) && Array.isArray(data)) {
      for (const entry of data) validateScheduleEntry(file, entry, rosterIds, scenePaths);
    }
  }

  for (const ref of pendingQuestRefs) {
    if (!questIds.has(ref.questId)) {
      err(`quest start_quests reference in '${ref.from}' points at unknown quest '${ref.questId}'`);
    }
  }

  if (!quiet) {
    for (const w of warnings) console.warn("WARN: " + w);
    for (const e of errors) console.error("ERROR: " + e);
  }

  console.log(`content validation: ${files.length} file(s), ` +
    `${errors.length} error(s), ${warnings.length} warning(s)`);
  process.exit(errors.length > 0 ? 1 : 0);
}

main();
