class_name SympathyTarget
extends Area2D

## SympathyTarget
# A world object that can only be dealt with through a sympathy working
# (GDD §8 applied out of combat): a jammed gate to move, a stuck hatch or
# door to open. Interacting requests a SympathyPuzzle from the owning scene;
# on success the node applies the working's world effect and sets its flag.

signal puzzle_requested(target: SympathyTarget)
signal already_resolved(target: SympathyTarget)

@export var working_id := ""
@export var display_name := ""
## Node affected by the working's world effect (barrier to unlock / object to move).
@export var obstacle_path: NodePath = NodePath()
## World-space offset applied when the effect is move_obstacle.
@export var move_offset := Vector2.ZERO

var is_resolved := false

var _prompt: Label = null
var _player_in_range := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_prompt()

func _setup_prompt() -> void:
	_prompt = Label.new()
	_prompt.name = "InteractPrompt"
	_prompt.text = "[E]"
	_prompt.add_theme_font_size_override("font_size", 10)
	_prompt.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	_prompt.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.12, 0.9))
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-14, -40)
	_prompt.size = Vector2(28, 14)
	_prompt.visible = false
	add_child(_prompt)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_in_range = true
		_prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_in_range = false
		_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		interact()

func interact() -> void:
	if is_resolved:
		AudioLibrary.play("SFX_UI_ERROR", -10.0)
		already_resolved.emit(self)
		return
	AudioLibrary.play("SFX_UI_CONFIRM", -6.0)
	puzzle_requested.emit(self)

## Loads this target's puzzle definition, ready for panel presentation.
func build_puzzle(rng: RandomNumberGenerator = null) -> SympathyPuzzle:
	var d := SympathyPuzzle.find_def(working_id)
	return SympathyPuzzle.new(d, rng)

## Applies a committed working result to the world. Pure callers may pass any
## dict shaped like SympathyPuzzle.commit()'s return value.
func apply_success(result: Dictionary) -> bool:
	if not result.get("success", false):
		return false
	is_resolved = true
	_prompt.visible = false

	var gs: Node = get_node_or_null("/root/GameState")
	var flag := str(result.get("flag", ""))
	if not flag.is_empty() and gs != null and gs.has_method("set_flag"):
		gs.call("set_flag", flag)

	var obstacle := get_node_or_null(obstacle_path) as Node2D
	match str(result.get("world_effect", "")):
		"open_door":
			AudioLibrary.play("SFX_DOOR_WOOD_OPEN", -4.0)
			if obstacle != null:
				_disable_collision(obstacle)
				if obstacle is Node2D:
					(obstacle as Node2D).visible = false
		"move_obstacle":
			AudioLibrary.play("SFX_WOOD_CREAK", -4.0)
			if obstacle != null:
				var tween := create_tween()
				if tween != null:
					tween.tween_property(obstacle, "position", obstacle.position + move_offset, 0.6)
				else:
					obstacle.position += move_offset
	return true

static func _disable_collision(node: Node) -> void:
	for child in node.find_children("*", "CollisionShape2D", true, false):
		(child as CollisionShape2D).disabled = true
	for child in node.find_children("*", "CollisionPolygon2D", true, false):
		(child as CollisionPolygon2D).disabled = true
