class_name SliceDirector
extends Node

## SliceDirector
# Orchestrates the Act I vertical-slice flow as a data-driven series of story beats.
# Loads beat definitions from `data/story/slice_flow.json`, tracks the current beat
# through GameState.quest_states, and advances when the beat's required flags are set.
# Designed to run headless: it does not instantiate scenes or depend on visual nodes.

const FLOW_PATH := "res://data/story/slice_flow.json"
const QUEST_STATE_INDEX_KEY := "slice_flow_act1_index"
const QUEST_STATE_BEAT_ID_KEY := "slice_flow_act1_beat_id"
const COMPLETION_FLAG := "vertical_slice_completed"

var _beats: Array[Dictionary] = []
var _flow_id: String = ""

func _init() -> void:
	_load_flow()

func _ready() -> void:
	# Ensure flow is loaded even if _init was skipped by certain instantiation paths.
	if _beats.is_empty():
		_load_flow()

func _load_flow() -> void:
	_beats.clear()

	var file := FileAccess.open(FLOW_PATH, FileAccess.READ)
	if file == null:
		push_error("SliceDirector: failed to open '%s'" % FLOW_PATH)
		return

	var raw := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null or not parsed is Dictionary:
		push_error("SliceDirector: '%s' is not valid JSON" % FLOW_PATH)
		return

	var data: Dictionary = parsed as Dictionary
	_flow_id = data.get("id", "")

	var raw_beats: Variant = data.get("beats")
	if raw_beats == null or not raw_beats is Array:
		push_error("SliceDirector: '%s' missing 'beats' array" % FLOW_PATH)
		return

	for entry: Variant in raw_beats:
		if entry is Dictionary:
			_beats.append(entry as Dictionary)

## Returns the beat that is currently active, or an empty dictionary if none.
func get_current_beat() -> Dictionary:
	var index := _current_index()
	if index < 0 or index >= _beats.size():
		return {}
	return _beats[index]

## Returns true when the current beat's required flags are all set in GameState.
func can_advance() -> bool:
	var beat := get_current_beat()
	if beat.is_empty():
		return false

	var required: Array = beat.get("requires", [])
	if required.is_empty():
		return true

	var gs := _game_state()
	if gs == null:
		return false

	for entry: Variant in required:
		if not entry is String:
			continue
		var flag: String = entry as String
		if not gs.has_flag(flag):
			return false
	return true

## Attempts to complete the current beat and move to the next one.
## Sets the beat's completion flag, persists the new index in GameState.quest_states,
## and optionally autosaves. Returns true if the slice advanced at least one step.
func advance_beat() -> bool:
	var start_index := _current_index()
	var beat := get_current_beat()
	if beat.is_empty():
		return false
	if not can_advance():
		return false

	var gs := _game_state()
	if gs == null:
		return false

	var sets_flag: String = beat.get("sets_flag", "")
	if not sets_flag.is_empty():
		gs.set_flag(sets_flag)

	var next_index := start_index + 1
	gs.quest_states[QUEST_STATE_INDEX_KEY] = next_index
	gs.quest_states[QUEST_STATE_BEAT_ID_KEY] = _beat_id_at(next_index)

	if beat.get("autosave", false) == true:
		_autosave()

	if next_index >= _beats.size():
		gs.set_flag(COMPLETION_FLAG)

	return true

## Returns true when the vertical slice has been fully completed.
func is_slice_complete() -> bool:
	var gs := _game_state()
	if gs == null:
		return false
	return gs.has_flag(COMPLETION_FLAG)

## Resets the tracked beat index to the start. Useful for clean-save tests.
func reset_progress() -> void:
	var gs := _game_state()
	if gs == null:
		return
	gs.quest_states[QUEST_STATE_INDEX_KEY] = 0
	gs.quest_states[QUEST_STATE_BEAT_ID_KEY] = _beat_id_at(0)

func _current_index() -> int:
	var gs := _game_state()
	if gs == null:
		return 0
	var stored: Variant = gs.quest_states.get(QUEST_STATE_INDEX_KEY)
	if stored == null or not stored is int:
		return 0
	var index: int = stored as int
	if index < 0 or index > _beats.size():
		return 0
	return index

func _beat_id_at(index: int) -> String:
	if index < 0 or index >= _beats.size():
		return ""
	var beat: Dictionary = _beats[index]
	return beat.get("id", "")

func _game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _autosave() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	if sm.has_method("save_game"):
		var _result: Variant = sm.call("save_game", 0)
