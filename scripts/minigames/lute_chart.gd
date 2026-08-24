## LuteChart
# RefCounted data container for a lute rhythm chart.
# Loads JSON, validates the schema, and provides beat/time conversion
# plus note lookup by window. Supports accessibility density scaling.
class_name LuteChart
extends RefCounted

var id: String = ""
var title: String = ""
var bpm: float = 120.0
var length_beats: float = 16.0
var notes: Array[Dictionary] = []

var _source_notes: Array[Dictionary] = []
var _density_scale: float = 1.0

const MAX_LANE_INDEX: int = 3
const MIN_LANE_INDEX: int = 0

func load_from_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("LuteChart: failed to open file: %s" % path)
		return false
	var json_text := file.get_as_text()
	file.close()
	return load_from_text(json_text)

func load_from_text(json_text: String) -> bool:
	var parsed = JSON.parse_string(json_text)
	if parsed == null or not parsed is Dictionary:
		push_error("LuteChart: JSON did not parse to a dictionary")
		return false
	var data: Dictionary = parsed
	return _load_from_dict(data)

func _load_from_dict(data: Dictionary) -> bool:
	var required_keys := ["id", "title", "bpm", "length_beats", "notes"]
	for key in required_keys:
		if not data.has(key):
			push_error("LuteChart: missing required key '%s'" % key)
			return false

	id = str(data.get("id", ""))
	title = str(data.get("title", ""))
	bpm = float(data.get("bpm", 120.0))
	length_beats = float(data.get("length_beats", 16.0))

	var raw_notes = data.get("notes", [])
	if raw_notes == null or not raw_notes is Array:
		push_error("LuteChart: 'notes' must be an array")
		return false

	_source_notes.clear()
	notes.clear()

	for raw in raw_notes:
		if raw == null or not raw is Dictionary:
			continue
		var note: Dictionary = raw
		var t: float = float(note.get("t", 0.0))
		var lane: int = int(note.get("lane", -1))
		if lane < MIN_LANE_INDEX or lane > MAX_LANE_INDEX:
			push_warning("LuteChart: note at beat %f has invalid lane %d; skipped" % [t, lane])
			continue
		var clean := {"t": t, "lane": lane}
		_source_notes.append(clean)

	_source_notes.sort_custom(_sort_by_time)
	for note in _source_notes:
		notes.append(note.duplicate())

	_density_scale = 1.0
	return true

func apply_density_scale(scale: float) -> void:
	_density_scale = clampf(scale, 0.01, 4.0)
	notes.clear()
	if _source_notes.is_empty():
		return

	if _density_scale >= 1.0:
		for note in _source_notes:
			notes.append(note.duplicate())
		return

	var keep_every := int(roundf(1.0 / _density_scale))
	if keep_every < 1:
		keep_every = 1
	var idx := 0
	for note in _source_notes:
		if idx % keep_every == 0:
			notes.append(note.duplicate())
		idx += 1

func reset_density() -> void:
	apply_density_scale(1.0)

func get_density_scale() -> float:
	return _density_scale

func time_to_beats(time_seconds: float) -> float:
	return time_seconds * bpm / 60.0

func beats_to_time(beats: float) -> float:
	return beats * 60.0 / bpm

func get_notes_in_window(start_beats: float, end_beats: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for note in notes:
		var t: float = float(note.get("t", 0.0))
		if t >= start_beats and t <= end_beats:
			result.append(note)
	return result

func clear_hits() -> void:
	for note in notes:
		note.erase("hit")

func _sort_by_time(a: Variant, b: Variant) -> bool:
	if not a is Dictionary or not b is Dictionary:
		return false
	var da: Dictionary = a
	var db: Dictionary = b
	return float(da.get("t", 0.0)) < float(db.get("t", 0.0))
