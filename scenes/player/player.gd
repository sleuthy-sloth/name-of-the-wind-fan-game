extends CharacterBody2D

@export var speed: float = 140.0
## Base path (no extension) of the LPC sheet; falls back to the placeholder
## Sprite2D when unset or missing so tests and early scenes keep working.
@export var lpc_sheet: String = "res://art/sprites/lpc/kvothe_caravan"

const WALK_FPS := 9.0
const IDLE_FPS := 3.0

var _sprite: LpcSprite = null
var _placeholder: Sprite2D = null
var _facing := "down"
var _moving := false

func _ready() -> void:
	_placeholder = get_node_or_null("Sprite2D") as Sprite2D
	if lpc_sheet != "":
		var animated := LpcSprite.new()
		animated.name = "LpcSprite"
		if animated.load_sheet(lpc_sheet):
			animated.offset = Vector2(0, -18)  # feet on collision center
			add_child(animated)
			animated.play("idle")
			_sprite = animated
			if _placeholder != null:
				_placeholder.visible = false

func _physics_process(_delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * speed
	move_and_slide()
	_moving = input_direction.length_squared() > 0.01
	if _moving:
		_update_facing(input_direction)
	_update_animation()

func _update_facing(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		_facing = "right" if dir.x > 0 else "left"
	else:
		_facing = "down" if dir.y > 0 else "up"

func _update_animation() -> void:
	var target_anim := "walk" if _moving else "idle"
	if _sprite != null and _sprite.has_animation(target_anim):
		_sprite.set_direction(_facing)
		_sprite.set_fps(WALK_FPS if _moving else IDLE_FPS)
		_sprite.play(target_anim)
	elif _placeholder != null and not _moving:
		pass  # placeholder has no idle frame; leave as-is

func facing() -> String:
	return _facing
