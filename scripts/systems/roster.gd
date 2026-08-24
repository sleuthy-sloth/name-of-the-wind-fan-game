class_name Roster
extends RefCounted

## Roster loads troupe relationship records and applies deltas through a
## relationships holder (typically GameState, or a plain Dictionary in tests).
## State is intentionally not duplicated here; it lives in the holder's
## `relationships` dictionary so save/load round-trips automatically.

const DEFAULT_ROSTER_PATH := "res://data/characters/troupe_roster.json"

var _members: Dictionary = {}  # id -> member record
var _relationships: Dictionary = {}

func _init(relationships_holder = null, roster_path: String = DEFAULT_ROSTER_PATH) -> void:
	load_from_file(roster_path)
	set_relationships_holder(relationships_holder)

func set_relationships_holder(holder) -> void:
	if holder == null:
		_relationships = {}
	elif holder is Node:
		_relationships = holder.relationships
	elif holder is Dictionary:
		_relationships = holder
	else:
		push_warning("Roster: unsupported relationships holder type")
		_relationships = {}

func load_from_file(path: String) -> void:
	_members.clear()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Roster: failed to open '%s'" % path)
		return

	var json_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or not parsed is Dictionary:
		push_warning("Roster: failed to parse '%s' as JSON" % path)
		return

	var data: Dictionary = parsed
	var members_array: Array = data.get("members", [])
	for entry in members_array:
		if not entry is Dictionary:
			continue
		var member: Dictionary = entry
		var id: String = member.get("id", "")
		if id.is_empty():
			continue
		_members[id] = member

func get_member(id: String) -> Dictionary:
	return _members.get(id, {})

func list_members() -> Array:
	return _members.keys()

func get_relationship(id: String) -> float:
	var member := get_member(id)
	var base: float = member.get("base_relationship", 0.0)
	return _relationships.get(id, base)

func apply_relationship_delta(id: String, delta: float) -> void:
	if not _members.has(id):
		push_warning("Roster: cannot apply delta to unknown member '%s'" % id)
		return
	var next_value: float = get_relationship(id) + delta
	_relationships[id] = next_value
