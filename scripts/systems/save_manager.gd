## SaveManager
# Versioned JSON save/load system per GDD §20.4.
# Save migrations become required whenever serialized fields change.
extends Node

const SAVE_VERSION := 1
const SAVE_DIR := "user://saves"

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

	if parsed.get("version", 0) != SAVE_VERSION:
		push_warning("SaveManager: save slot %d version mismatch" % slot)
		return false

	var state: Variant = parsed.get("state")
	if state == null or typeof(state) != TYPE_DICTIONARY:
		push_warning("SaveManager: save slot %d missing state" % slot)
		return false

	var gs = _gs()
	if gs == null:
		push_error("SaveManager: GameState not found")
		return false

	gs.from_dict(state)
	return true

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))

func delete_save(slot: int) -> void:
	var path := slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
