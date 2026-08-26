class_name MinigameHost
extends CanvasLayer

## MinigameHost
# Reusable host for performance/skill minigames (lute, sympathy, future ones)
# per GDD Phase 2. Owns the minigame lifecycle so games only implement:
#   * a Node with `setup(params: Dictionary)` (optional) and
#   * signal `finished(result: Dictionary)` plus `get_minigame_id() -> String`
#     (or an id passed to the host at launch).
#
# The host pauses world input handling by design of its layer, emits
# `minigame_finished` with the game's result dictionary, and frees the game.
# Launching by path keeps scene/data templates decoupled from gameplay code.

signal minigame_started(minigame_id: String)
signal minigame_finished(minigame_id: String, result: Dictionary)
signal minigame_cancelled(minigame_id: String)

const HOST_GROUP := "minigame_host"

var _current_id: String = ""
var _current_game: Node = null
var _busy: bool = false

func _ready() -> void:
	add_to_group(HOST_GROUP)
	layer = 90

func is_running() -> bool:
	return _busy and _current_game != null

func current_minigame_id() -> String:
	return _current_id

## Launch a minigame from a packed scene path. Returns false when a game is
## already running or the scene cannot load.
func start(minigame_scene_path: String, params: Dictionary = {}, forced_id: String = "") -> bool:
	var packed: PackedScene = load(minigame_scene_path)
	if packed == null:
		push_warning("MinigameHost: cannot load '%s'" % minigame_scene_path)
		return false
	var game := packed.instantiate()
	return start_with_node(game, params, forced_id)

## Launch with a pre-built node (used by tests and programmatic hosts).
func start_with_node(game: Node, params: Dictionary = {}, forced_id: String = "") -> bool:
	if _busy:
		push_warning("MinigameHost: '%s' still running" % _current_id)
		return false
	if game == null:
		return false

	_current_game = game
	_busy = true
	_current_id = forced_id
	if _current_id.is_empty() and game.has_method("get_minigame_id"):
		_current_id = str(game.call("get_minigame_id"))
	if _current_id.is_empty():
		_current_id = "minigame_unnamed"

	add_child(game)
	if game.has_method("setup"):
		game.call("setup", params)

	game.connect("finished", _on_game_finished)
	minigame_started.emit(_current_id)
	return true

func cancel() -> bool:
	if not is_running():
		return false
	var id := _current_id
	_teardown()
	minigame_cancelled.emit(id)
	return true

func _on_game_finished(result: Dictionary) -> void:
	var id := _current_id
	_teardown()
	minigame_finished.emit(id, result)

func _teardown() -> void:
	if _current_game != null and is_instance_valid(_current_game):
		_current_game.queue_free()
	_current_game = null
	_current_id = ""
	_busy = false

## Group-based lookup that works in headless tests where autoloads may be absent.
static func find_host(tree_root: Node) -> MinigameHost:
	var nodes := tree_root.get_tree().get_nodes_in_group(HOST_GROUP) if tree_root != null else []
	for n: Variant in nodes:
		if n is MinigameHost:
			return n as MinigameHost
	return null
