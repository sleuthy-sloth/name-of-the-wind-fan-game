## SaveManager
# Versioned JSON save/load system per GDD §20.4.
# Save migrations become required whenever serialized fields change.
# Migrations run stepwise (v1->v2->...) on load; payloads newer than
# SAVE_VERSION fail closed. Systems needing their own persisted state join
# the "save_contributors" group and implement collect_save_state() ->
# Dictionary and apply_save_state(d: Dictionary).
extends Node

const SAVE_VERSION := 2
const SAVE_DIR := "user://saves"
const CONTRIBUTORS_GROUP := "save_contributors"

## Stepwise migrations: source version -> Callable(payload) -> payload.
## Each returns the upgraded payload; unknown source versions fail closed.
var _migrations: Dictionary = {}

func _init() -> void:
	_migrations[1] = _migrate_v1_to_v2

func _migrate_v1_to_v2(payload: Dictionary) -> Dictionary:
	# v1 stored only GameState state. v2 adds per-manager state contributed by
	# nodes in the save_contributors group; older saves start empty.
	payload["version"] = 2
	if not payload.has("managers"):
		payload["managers"] = {}
	return payload

func _gs() -> Variant:
	var singleton := get_node_or_null("/root/GameState")
	if singleton != null:
		return singleton
	for child in get_tree().root.get_children():
		if child.is_class("Node") and child.get_script() != null:
			if child.get_script().resource_path.ends_with("game_state.gd"):
				return child
	return null

func slot_path(slot: int) -> String:
	return SAVE_DIR.path_join("slot_%d.json" % slot)

func save_game(slot: int) -> bool:
	var gs = _gs()
	if gs == null:
		push_error("SaveManager: GameState not found")
		return false

	var scene_path := ""
	if get_tree().current_scene != null and get_tree().current_scene.scene_file_path != "":
		scene_path = get_tree().current_scene.scene_file_path

	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"state": gs.to_dict(),
		"scene_path": scene_path,
	}

	var managers := {}
	for contributor in get_tree().get_nodes_in_group(CONTRIBUTORS_GROUP):
		if contributor.has_method("collect_save_state"):
			var contributed: Variant = contributor.call("collect_save_state")
			if contributed is Dictionary:
				var key := str(contributor.name)
				if contributor.has_method("save_state_id"):
					key = str(contributor.call("save_state_id"))
				contributed["__manager_id"] = key
				managers[key] = contributed
	payload["managers"] = managers

	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open save slot %d (error %d)" % [slot, FileAccess.get_open_error()])
		return false

	file.store_string(JSON.stringify(payload))
	file.close()
	return true

func load_game(slot: int) -> bool:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: failed to read save slot %d (error %d)" % [slot, FileAccess.get_open_error()])
		return false

	var raw := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: save slot %d is corrupt" % slot)
		return false

	var version := int(parsed.get("version", 0))
	if version > SAVE_VERSION:
		push_warning("SaveManager: save slot %d is from a newer version (%d > %d)" % [slot, version, SAVE_VERSION])
		return false
	while version < SAVE_VERSION:
		if not _migrations.has(version):
			push_warning("SaveManager: no migration for save version %d (slot %d)" % [version, slot])
			return false
		var migrate: Callable = _migrations[version]
		var upgraded: Variant = migrate.call(parsed)
		if upgraded == null or typeof(upgraded) != TYPE_DICTIONARY:
			push_warning("SaveManager: migration %d failed for slot %d" % [version, slot])
			return false
		parsed = upgraded as Dictionary
		version = int(parsed.get("version", version + 1))

	var state: Variant = parsed.get("state")
	if state == null or typeof(state) != TYPE_DICTIONARY:
		push_warning("SaveManager: save slot %d missing state" % slot)
		return false

	var gs = _gs()
	if gs == null:
		push_error("SaveManager: GameState not found")
		return false

	gs.from_dict(state)

	var managers: Variant = parsed.get("managers", {})
	if typeof(managers) == TYPE_DICTIONARY:
		for contributor in get_tree().get_nodes_in_group(CONTRIBUTORS_GROUP):
			if not contributor.has_method("apply_save_state"):
				continue
			var key := str(contributor.name)
			if contributor.has_method("save_state_id"):
				key = str(contributor.call("save_state_id"))
			var contributed: Variant = (managers as Dictionary).get(key)
			if contributed is Dictionary:
				contributor.call("apply_save_state", contributed as Dictionary)
	return true

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))

func delete_save(slot: int) -> void:
	var path := slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
