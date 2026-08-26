extends Node

## QuestManager
# Data-driven quest system per GDD Phase 2. Quest definitions live in
# `data/quests/*.json`; runtime state is stored in GameState.quest_states
# under the quest id so saves persist progress without extra plumbing.
#
# Definition shape:
#   {
#     "quest_id": "quest_act1_example",
#     "title": "Example",
#     "auto_start": false,
#     "stages": [
#       {
#         "stage_id": "stage_talk",
#         "objectives": [
#           {"objective_id": "obj_flag",  "type": "flag",         "flag": "flag_x"},
#           {"objective_id": "obj_item",  "type": "item",         "item": "item_x", "count": 2},
#           {"objective_id": "obj_rel",   "type": "relationship", "character": "char_abenthy", "min": 3.0}
#         ],
#         "on_complete": {
#           "set_flags": ["flag_y"],
#           "relationships": [{"character": "char_abenthy", "delta": 1.0}],
#           "reputation": [{"group": "ruh", "delta": 1}],
#           "start_quests": ["quest_other"]
#         }
#       }
#     ]
#   }
#
# Gameplay code reports world events through notify_* helpers; the manager
# evaluates active objectives and completes stages automatically.

signal quest_started(quest_id: String)
signal stage_completed(quest_id: String, stage_id: String)
signal quest_completed(quest_id: String)

const QUESTS_DIR := "res://data/quests"
const OBJECTIVE_TYPES := ["flag", "item", "relationship"]

var _quests: Dictionary = {}      # quest_id -> definition Dictionary
var _load_errors: Array[String] = []

func _ready() -> void:
	load_all()

func load_all() -> int:
	_quests.clear()
	_load_errors.clear()
	var dir := DirAccess.open(QUESTS_DIR)
	if dir == null:
		push_warning("QuestManager: no quests directory at %s" % QUESTS_DIR)
		return 0
	for entry in dir.get_files():
		if not entry.ends_with(".json"):
			continue
		var path := QUESTS_DIR.path_join(entry)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_load_errors.append("%s: unreadable" % path)
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed == null or not parsed is Dictionary:
			_load_errors.append("%s: invalid JSON" % path)
			continue
		var def: Dictionary = parsed as Dictionary
		var qid := str(def.get("quest_id", ""))
		if qid.is_empty():
			_load_errors.append("%s: missing quest_id" % path)
			continue
		_quests[qid] = def
	return _quests.size()

func get_quest_ids() -> Array:
	return _quests.keys()

func get_quest(quest_id: String) -> Dictionary:
	return _quests.get(quest_id, {})

## Structural validation for tooling and tests; mirrors DialogueRunner.validate().
func validate() -> Array[String]:
	var errors: Array[String] = []
	for qid in _quests:
		var def: Dictionary = _quests[qid]
		if def.get("title", "") == "":
			errors.append("%s: missing title" % qid)
		var stages: Variant = def.get("stages")
		if stages == null or not stages is Array or (stages as Array).is_empty():
			errors.append("%s: missing stages array" % qid)
			continue
		var seen_stages := {}
		for stage: Variant in stages:
			if not stage is Dictionary:
				errors.append("%s: non-object stage" % qid)
				continue
			var sd: Dictionary = stage as Dictionary
			var sid := str(sd.get("stage_id", ""))
			if sid.is_empty():
				errors.append("%s: stage missing stage_id" % qid)
			elif seen_stages.has(sid):
				errors.append("%s: duplicate stage '%s'" % [qid, sid])
			seen_stages[sid] = true
			var objectives: Variant = sd.get("objectives")
			if objectives == null or not objectives is Array or (objectives as Array).is_empty():
				errors.append("%s/%s: no objectives" % [qid, sid])
				continue
			for obj: Variant in objectives:
				if not obj is Dictionary:
					errors.append("%s/%s: non-object objective" % [qid, sid])
					continue
				var od: Dictionary = obj as Dictionary
				var otype := str(od.get("type", ""))
				if not OBJECTIVE_TYPES.has(otype):
					errors.append("%s/%s: unknown objective type '%s'" % [qid, sid, otype])
				if str(od.get("objective_id", "")) == "":
					errors.append("%s/%s: objective missing objective_id" % [qid, sid])
	return errors

# --- state access -----------------------------------------------------------

func _state(quest_id: String) -> Dictionary:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return {}
	var stored: Variant = gs.quest_states.get(quest_id)
	if stored is Dictionary and (stored as Dictionary).get("__tracked", false) == true:
		return stored
	return {}

func start_quest(quest_id: String) -> bool:
	if not _quests.has(quest_id):
		push_warning("QuestManager: unknown quest '%s'" % quest_id)
		return false
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return false
	if gs.quest_states.get(quest_id, {}).get("completed", false) == true:
		return false
	gs.quest_states[quest_id] = {"__tracked": true, "stage_index": 0,
		"completed": false, "objectives": {}}
	quest_started.emit(quest_id)
	_evaluate_stage(quest_id)
	return true

func is_active(quest_id: String) -> bool:
	var s := _state(quest_id)
	return not s.is_empty() and s.get("completed", false) != true

func is_completed(quest_id: String) -> bool:
	var s := _state(quest_id)
	return s.get("completed", false) == true

func current_stage_id(quest_id: String) -> String:
	var s := _state(quest_id)
	if s.is_empty():
		return ""
	var def: Dictionary = _quests.get(quest_id, {})
	var stages: Array = def.get("stages", [])
	var idx: int = s.get("stage_index", 0)
	if idx < 0 or idx >= stages.size():
		return ""
	return str((stages[idx] as Dictionary).get("stage_id", ""))

func objective_progress(quest_id: String, objective_id: String) -> float:
	var s := _state(quest_id)
	var recorded: Variant = s.get("objectives", {}).get(objective_id)
	if recorded != null:
		return float(recorded)
	return -1.0

# --- event hooks ------------------------------------------------------------

func notify_flag(flag_id: String) -> void:
	_evaluate_all("flag", flag_id)

func notify_item(item_id: String, count: int) -> void:
	_evaluate_all("item", item_id, count)

func notify_relationship(character_id: String) -> void:
	_evaluate_all("relationship", character_id)

# --- evaluation -------------------------------------------------------------

func _evaluate_all(type: String, target: String, count: int = 0) -> void:
	for qid in _state_keys():
		if not is_active(qid):
			continue
		_evaluate_stage(qid, type, target, count)

func _state_keys() -> Array:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return []
	return gs.quest_states.keys()

func _evaluate_stage(quest_id: String, type: String = "", target: String = "", count: int = 0) -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var state := _state(quest_id)
	if state.is_empty():
		return
	var def: Dictionary = _quests.get(quest_id, {})
	var stages: Array = def.get("stages", [])

	while true:
		var idx: int = state.get("stage_index", 0)
		if idx >= stages.size():
			break
		var stage: Dictionary = stages[idx] as Dictionary
		var objectives: Array = stage.get("objectives", [])
		var all_met := true
		for obj: Variant in objectives:
			var od: Dictionary = obj as Dictionary
			if type != "" and str(od.get("type", "")) == type and _target_of(od) == target:
				_record_progress(state, od, count)
			if not _objective_met(gs, od, state):
				all_met = false
		state["objectives"] = state.get("objectives", {})
		gs.quest_states[quest_id] = state

		if all_met:
			_apply_on_complete(stage.get("on_complete", {}))
			stage_completed.emit(quest_id, str(stage.get("stage_id", "")))
			state["stage_index"] = idx + 1
			state["objectives"] = {}
			gs.quest_states[quest_id] = state
			if state["stage_index"] >= stages.size():
				state["completed"] = true
				gs.quest_states[quest_id] = state
				quest_completed.emit(quest_id)
				return
			continue  # evaluate next stage immediately (chainable instant stages)
		break

func _target_of(od: Dictionary) -> String:
	match str(od.get("type", "")):
		"flag":
			return str(od.get("flag", ""))
		"item":
			return str(od.get("item", ""))
		"relationship":
			return str(od.get("character", ""))
	return ""

func _record_progress(state: Dictionary, od: Dictionary, count: int) -> void:
	var oid := str(od.get("objective_id", ""))
	var objectives: Dictionary = state.get("objectives", {})
	match str(od.get("type", "")):
		"item":
			objectives[oid] = float(objectives.get(oid, 0.0)) + float(count)
		_:
			objectives[oid] = true
	state["objectives"] = objectives

func _objective_met(gs: Node, od: Dictionary, state: Dictionary) -> bool:
	var oid := str(od.get("objective_id", ""))
	var recorded: Variant = state.get("objectives", {}).get(oid)
	match str(od.get("type", "")):
		"flag":
			return recorded == true or gs.has_flag(str(od.get("flag", "")))
		"item":
			var need := float(od.get("count", 1))
			return recorded != null and float(recorded) >= need
		"relationship":
			var min_val := float(od.get("min", 0.0))
			return recorded == true or float(gs.relationships.get(str(od.get("character", "")), 0.0)) >= min_val
	return false

func _apply_on_complete(on_complete: Dictionary) -> void:
	if on_complete.is_empty():
		return
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var rm := get_node_or_null("/root/RelationshipManager")
	for flag: Variant in on_complete.get("set_flags", []):
		gs.set_flag(str(flag))
	for rel: Variant in on_complete.get("relationships", []):
		if rm != null:
			rm.call("adjust_relationship", str(rel.get("character", "")), float(rel.get("delta", 0.0)))
		else:
			var cid := str(rel.get("character", ""))
			gs.relationships[cid] = float(gs.relationships.get(cid, 0.0)) + float(rel.get("delta", 0.0))
	for rep: Variant in on_complete.get("reputation", []):
		if rm != null:
			rm.call("adjust_reputation", str(rep.get("group", "")), int(rep.get("delta", 0)))
		else:
			var group := str(rep.get("group", ""))
			gs.reputation[group] = int(gs.reputation.get(group, 0)) + int(rep.get("delta", 0))
	for qid: Variant in on_complete.get("start_quests", []):
		start_quest(str(qid))
