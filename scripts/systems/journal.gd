## Journal
# Records discovered Sympathy bindings and their outcomes.
# Lightweight, serializable, and deduplicated by source/link/target/effect identity.
class_name Journal
extends RefCounted

var _entries: Array[Dictionary] = []

# Records a discovery. Repeated attempts update the existing entry's outcome
# and attempt count instead of creating duplicates.
func add_entry(source_id: String, link_id: String, target_id: String, effect_id: String, outcome: String) -> void:
	var key := _make_key(source_id, link_id, target_id, effect_id)
	for entry: Dictionary in _entries:
		if entry.get("key", "") == key:
			entry["outcome"] = outcome
			entry["attempt_count"] = entry.get("attempt_count", 1) + 1
			entry["last_updated"] = Time.get_unix_time_from_system()
			return
	_entries.append({
		"key": key,
		"source_id": source_id,
		"link_id": link_id,
		"target_id": target_id,
		"effect_id": effect_id,
		"outcome": outcome,
		"attempt_count": 1,
		"discovered_at": Time.get_unix_time_from_system(),
	})

func list_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)

func entry_count() -> int:
	return _entries.size()

func clear() -> void:
	_entries.clear()

func to_dict() -> Dictionary:
	return {
		"entries": _entries.duplicate(true),
	}

func from_dict(d: Dictionary) -> void:
	_entries = d.get("entries", []).duplicate(true)

func _make_key(source_id: String, link_id: String, target_id: String, effect_id: String) -> String:
	return "%s|%s|%s|%s" % [source_id, link_id, target_id, effect_id]
