class_name Npc
extends StaticBody2D

@export var npc_id := "npc_unnamed"
@export var display_name := ""
@export var dialogue_path := ""
## Base path (no extension) of an LPC sheet for this NPC's visuals.
## When empty the placeholder child sprite is shown instead.
@export var lpc_sheet := ""
## Direction the NPC idles facing (up|left|down|right).
@export var idle_facing := "down"

var can_interact := false
var _runner: DialogueRunner = null
var _sprite: LpcSprite = null
var _prompt: Label = null

@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	_setup_visuals()
	_setup_prompt()

func _setup_visuals() -> void:
	if lpc_sheet == "":
		return
	var animated := LpcSprite.new()
	animated.name = "LpcSprite"
	if animated.load_sheet(lpc_sheet):
		animated.offset = Vector2(0, -18)  # feet on collision center
		add_child(animated)
		animated.set_direction(idle_facing)
		animated.play("idle")
		_sprite = animated
		var placeholder := get_node_or_null("Sprite2D") as Sprite2D
		if placeholder != null:
			placeholder.visible = false

func _setup_prompt() -> void:
	_prompt = Label.new()
	_prompt.name = "InteractPrompt"
	InteractionPrompt.configure(_prompt, &"interact", display_name, Color(1.0, 0.96, 0.85))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-12, -46)
	_prompt.size = Vector2(24, 14)
	_prompt.visible = false
	add_child(_prompt)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		can_interact = true
		_set_prompt_visible(true)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		can_interact = false
		_set_prompt_visible(false)

func _set_prompt_visible(value: bool) -> void:
	if _prompt != null:
		_prompt.visible = value

func _unhandled_input(event: InputEvent) -> void:
	if can_interact and event.is_action_pressed("interact"):
		interact()

func interact() -> void:
	AudioLibrary.play("SFX_UI_CONFIRM", -6.0)
	if dialogue_path.is_empty():
		push_warning("Npc '%s' has no dialogue_path set" % npc_id)
		return

	var file := FileAccess.open(dialogue_path, FileAccess.READ)
	if file == null:
		push_error("Npc '%s' failed to open dialogue file: %s" % [npc_id, dialogue_path])
		return

	var json_text := file.get_as_text()
	file.close()

	var result: Variant = JSON.parse_string(json_text)
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
