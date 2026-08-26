extends Node

## ScheduleSystem
# Data-driven NPC schedules per GDD Phase 2. Definitions live in
# `data/schedules/*.json`; each entry maps an npc_id to a default location
# plus conditional overrides. Resolution is pure data + GameState lookups so
# it runs headless in tests.
#
# Definition shape:
#   {
#     "npc_id": "char_abenthy",
#     "default": {"scene": "res://scenes/world/forest_campsite.tscn", "marker": "marker_campfire"},
#     "overrides": [
#       {
#         "when": {"acts": [1], "days": [1, 2], "time_blocks": ["evening"], "flags": ["flag_x"]},
#         "scene": "...", "marker": "..."
#       }
#     ]
#   }
#
# All `when` keys are optional; within one override they AND together, and
# listed values OR. The LAST matching override wins (order = priority).
# Overrides may also carry "hide": true when the NPC is absent.

signal schedule_resolved(npc_id: String, location: Dictionary)

const SCHEDULES_DIR := "res://data/schedules"
const TIME_BLOCKS := ["morning", "afternoon", "evening", "night"]

var _entries: Dictionary = {}     # npc_id -> entry Dictionary
var _load_errors: Array[String] = []

func _ready() -> void:
	load_all()

func load_all() -> int:
	_entries.clear()
	_load_errors.clear()
	var dir := DirAccess.open(SCHEDULES_DIR)
	if dir == null:
		push_warning("ScheduleSystem: no schedules directory at %s" % SCHEDULES_DIR)
		return 0
	for entry in dir.get_files():
		if not entry.ends_with(".json"):
			continue
		var path := SCHEDULES_DIR.path_join(entry)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_load_errors.append("%s: unreadable" % path)
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed == null or not parsed is Array:
			_load_errors.append("%s: expected array of entries" % path)
			continue
		for raw: Variant in parsed:
			if not raw is Dictionary:
				_load_errors.append("%s: non-object entry" % path)
				continue
			var e: Dictionary = raw as Dictionary
			var npc_id := str(e.get("npc_id", ""))
			if npc_id.is_empty():
				_load_errors.append("%s: entry missing npc_id" % path)
				continue
			if _entries.has(npc_id):
				_load_errors.append("%s: duplicate npc_id '%s'" % [path, npc_id])
				continue
			_entries[npc_id] = e
	return _entries.size()

func has_schedule(npc_id: String) -> bool:
	return _entries.has(npc_id)

func get_npc_ids() -> Array:
	return _entries.keys()

## Resolve where an NPC is for the given context. Returns {} when the NPC has
## no schedule or an override hides them; otherwise {"scene", "marker"?}.
func resolve(npc_id: String, act: int, day: int, time_block: String) -> Dictionary:
	var entry: Dictionary = _entries.get(npc_id, {})
	if entry.is_empty():
		return {}
	var resolved: Dictionary = entry.get("default", {}).duplicate()
	for override: Variant in entry.get("overrides", []):
		if not override is Dictionary:
			continue
		if _override_matches(override as Dictionary, act, day, time_block):
			var ov: Dictionary = override as Dictionary
			if ov.get("hide", false) == true:
				return {}
			for key in ["scene", "marker"]:
				if ov.has(key):
					resolved[key] = ov[key]
	schedule_resolved.emit(npc_id, resolved)
	return resolved

## Convenience wrapper resolving against the live GameState.
func resolve_now(npc_id: String) -> Dictionary:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return resolve(npc_id, 1, 1, "morning")
	return resolve(npc_id, gs.act, gs.day, gs.time_block)

## Structural validation used by tools/validate_content.mjs conventions and tests.
func validate() -> Array[String]:
	var errors: Array[String] = []
	for npc_id in _entries:
		var e: Dictionary = _entries[npc_id]
		if str(e.get("default", {}).get("scene", "")) == "":
			errors.append("%s: default scene missing" % npc_id)
		for override: Variant in e.get("overrides", []):
			var ov: Dictionary = override as Dictionary
			var has_scene := str(ov.get("scene", "")) != ""
			var has_marker := str(ov.get("marker", "")) != ""
			var is_hidden: bool = ov.get("hide", false) == true
			if not (has_scene or has_marker or is_hidden):
				errors.append("%s: override has no scene/marker/hide" % npc_id)
			var blocks: Variant = ov.get("when", {}).get("time_blocks", [])
			for block: Variant in blocks:
				if not TIME_BLOCKS.has(str(block)):
					errors.append("%s: unknown time block '%s'" % [npc_id, str(block)])
	return errors

func _int_list_matches(list: Variant, target: int) -> bool:
	var arr: Array = list if list is Array else []
	if arr.is_empty():
		return true  # absent condition matches everything
	for entry: Variant in arr:
		if typeof(entry) in [TYPE_INT, TYPE_FLOAT] and int(entry) == target:
			return true
	return false

func _override_matches(ov: Dictionary, act: int, day: int, time_block: String) -> bool:
	var cond: Dictionary = ov.get("when", {})
	# JSON numbers decode as floats; compare numerically.
	if not _int_list_matches(cond.get("acts", []), act):
		return false
	if not _int_list_matches(cond.get("days", []), day):
		return false
	var blocks: Array = cond.get("time_blocks", [])
	if not blocks.is_empty() and not blocks.has(time_block):
		return false
	var flags: Array = cond.get("flags", [])
	for flag: Variant in flags:
		var gs := get_node_or_null("/root/GameState")
		if gs == null or not gs.has_flag(str(flag)):
			return false
	var not_flags: Array = cond.get("not_flags", [])
	for flag: Variant in not_flags:
		var gs2 := get_node_or_null("/root/GameState")
		if gs2 != null and gs2.has_flag(str(flag)):
			return false
	return true
