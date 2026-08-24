class_name SceneDoor
extends Area2D

@export var target_scene: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		SceneRouter.change_scene(target_scene)
