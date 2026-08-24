extends CharacterBody2D

@export var speed: float = 140.0

var _sprite: Sprite2D = null
# Character sheet: 17 cols x 16 rows, 16px tiles.
# Row 0 = walk down, Row 1 = walk up, Row 2 = walk left, Row 3 = walk right.
const _DIR_REGIONS := {
	"down": Rect2(0, 0, 16, 16),
	"up": Rect2(0, 17, 16, 16),
	"left": Rect2(0, 34, 16, 16),
	"right": Rect2(0, 51, 16, 16),
}

func _ready() -> void:
	_sprite = get_node_or_null("Sprite2D") as Sprite2D

func _physics_process(_delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * speed
	move_and_slide()
	_update_sprite_direction(input_direction)

func _update_sprite_direction(dir: Vector2) -> void:
	if _sprite == null:
		return
	if dir.length_squared() < 0.01:
		return
	var key := "down"
	if abs(dir.x) > abs(dir.y):
		key = "right" if dir.x > 0 else "left"
	else:
		key = "down" if dir.y > 0 else "up"
	if _DIR_REGIONS.has(key):
		_sprite.region_rect = _DIR_REGIONS[key]
