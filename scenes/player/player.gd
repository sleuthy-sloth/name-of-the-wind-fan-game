extends CharacterBody2D

@export var speed: float = 140.0

func _ready() -> void:
	print("DEBUG player _ready")

func _physics_process(_delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * speed
	print("DEBUG player velocity: " + str(velocity) + " pos: " + str(global_position))
	move_and_slide()
