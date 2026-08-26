extends Node

## ExplorationMap
# Tracks which scenes the player has been through and which scene-to-scene
# edges (door traversals) connect them. Drives the JournalScreen map tab —
# visited nodes are lit; unvisited ones stay in fog of war. Connects to
# SceneRouter so every change_scene marks its destination as visited.
# Autoload singleton — no class_name.

signal scene_visited(scene_id: String, first_time: bool, position: Vector2)
signal edge_traversed(from_id: String, to_id: String)

const SCENE_REGISTRY_PATH := "res://data/journal/scene_registry.json"
const SAVE_ID := "exploration_map"

var _registry: Dictionary = {}
var _visited: Dictionary = {}
var _edges: Array[Dictionary] = []
var _router_node: Node = null

func _ready() -> void:
	add_to_group("save_contributors")
	_load_registry()
	_attach_to_router()

func save_state_id() -> String:
	return SAVE_ID

static func get_or(d: Dictionary, key: String, default_value: Variant) -> Variant:
	return default_value if not d.has(key) else d[key]

func _load_registry() -> void:
	if not FileAccess.file_exists(SCENE_REGISTRY_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENE_REGISTRY_PATH))
	if parsed is Dictionary:
		var raw_scenes: Variant = get_or(parsed as Dictionary, "scenes", [])
		for entry: Variant in raw_scenes:
			if entry is Dictionary:
				var id_str := str(get_or(entry as Dictionary, "id", ""))
				_registry[id_str] = entry as Dictionary

func _attach_to_router() -> void:
	_router_node = get_node_or_null("/root/SceneRouter")
	if _router_node != null and _router_node.has_signal("scene_changed"):
		_router_node.connect("scene_changed", _on_router_scene_changed)

func _on_router_scene_changed(scene_path: String) -> void:
	visit(scene_path)

## Mark a scene as visited from world scripts.
func visit(scene_id: String) -> bool:
	if scene_id.is_empty():
		return false
	var first_time := not _visited.has(scene_id)
	var data: Dictionary = get_or(_registry, scene_id, {})
	var pos_arr: Variant = get_or(data, "position", [0, 0])
	var position := Vector2(float(pos_arr[0]), float(pos_arr[1]))
	if first_time:
		_visited[scene_id] = {"position": position, "first_visited_at": Time.get_unix_time_from_system()}
	scene_visited.emit(scene_id, first_time, position)
	return first_time

## Record an edge the player traversed. Called by scene scripts when they
## change scene via a known door.
func traverse(from_scene: String, to_scene: String, via: String) -> void:
	var edge := {"from": from_scene, "to": to_scene, "via": via, "at": Time.get_unix_time_from_system()}
	_edges.append(edge)
	edge_traversed.emit(from_scene, to_scene)
	visit(to_scene)

# --- queries used by JournalScreen --------------------------------------------

func visited_scenes() -> Array:
	return _visited.keys()

func is_visited(scene_id: String) -> bool:
	return _visited.has(scene_id)

func edges() -> Array[Dictionary]:
	return _edges.duplicate()

func scene_position(scene_id: String) -> Vector2:
	var data: Dictionary = get_or(_registry, scene_id, {})
	if data.is_empty():
		return Vector2.ZERO
	var pos_arr: Variant = get_or(data, "position", [0, 0])
	return Vector2(float(pos_arr[0]), float(pos_arr[1]))

func scene_display_name(scene_id: String) -> String:
	var data: Dictionary = get_or(_registry, scene_id, {})
	return str(get_or(data, "display_name", scene_id))

func all_known_scenes() -> Array:
	return _registry.keys()

# --- save / load --------------------------------------------------------------

func collect_save_state() -> Dictionary:
	return {
		"visited": _visited.duplicate(true),
		"edges": _edges.duplicate(true),
	}

func apply_save_state(state: Dictionary) -> void:
	_visited.clear()
	var visited_data: Dictionary = get_or(state, "visited", {})
	for k in visited_data.keys():
		_visited[str(k)] = visited_data[k]
	_edges.clear()
	for e: Variant in get_or(state, "edges", []):
		if e is Dictionary:
			_edges.append(e as Dictionary)
