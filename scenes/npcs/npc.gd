class_name Npc
extends StaticBody2D

@export var npc_id := "npc_unnamed"
@export var display_name := ""
@export var dialogue_path := ""

var can_interact := false
var _runner: DialogueRunner = null

@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		can_interact = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		can_interact = false

func _unhandled_input(event: InputEvent) -> void:
	if can_interact and event.is_action_pressed("interact"):
		interact()

func interact() -> void:
	if dialogue_path.is_empty():
		push_warning("Npc '%s' has no dialogue_path set" % npc_id)
		return

	var file := FileAccess.open(dialogue_path, FileAccess.READ)
	if file == null:
		push_error("Npc '%s' failed to open dialogue file: %s" % [npc_id, dialogue_path])
		return

	var json_text := file.get_as_text()
	file.close()

	var result := JSON.parse_string(json_text)
	if result == null or not result is Dictionary:
		push_error("Npc '%s' dialogue file is not valid JSON: %s" % [npc_id, dialogue_path])
		return

	var data: Dictionary = result
	var errors := DialogueRunner.validate(data)
	if errors.size() > 0:
		push_warning("Npc '%s' dialogue validation failed: %s" % [npc_id, ", ".join(errors)])
		return

	if _runner == null:
		_runner = DialogueRunner.new()
		add_child(_runner)

	_runner.start(data)
