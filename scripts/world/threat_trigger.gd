class_name ThreatTrigger
extends Area2D

## ThreatTrigger
# A place in the world where trouble lives (GDD §7.5). Interacting opens the
# threat in the owning scene's ThreatPanel. Once the encounter resolves
# successfully and its success flag is set, the trigger removes itself so the
# road stays clear; unresolved or failed encounters can be retried.

signal threat_requested(trigger: ThreatTrigger)

@export var threat_id := ""
@export var display_name := ""

var _prompt: Label = null
var _player_in_range := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_visuals()
	_setup_prompt()

func _setup_visuals() -> void:
	# Small amber warning marker so threats read as interactables at a glance.
	var marker := ColorRect.new()
	marker.name = "Marker"
	marker.color = Color(0.78, 0.45, 0.2, 0.85)
	marker.offset_left = -5.0
	marker.offset_top = -5.0
	marker.offset_right = 5.0
	marker.offset_bottom = 5.0
	add_child(marker)

func _setup_prompt() -> void:
	_prompt = Label.new()
	_prompt.name = "InteractPrompt"
	var label_text := "[E]"
	if not display_name.is_empty():
		label_text = "[E] " + display_name
	_prompt.text = label_text
	_prompt.add_theme_font_size_override("font_size", 10)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.82, 0.6))
	_prompt.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02, 0.9))
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-40, -44)
	_prompt.size = Vector2(80, 14)
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
	AudioLibrary.play("SFX_UI_CONFIRM", -6.0)
	threat_requested.emit(self)

func build_threat(rng: RandomNumberGenerator = null) -> ThreatEncounter:
	return ThreatEncounter.new(ThreatEncounter.find_def(threat_id), rng)

## Called by the owning scene after the panel closes. Successful resolution
## (success flag present) retires this trigger; failures leave it for a retry.
func resolve_after_encounter(threat: ThreatEncounter, outcome: Dictionary) -> void:
	if not bool(outcome.get("resolved", false)):
		return
	if bool(outcome.get("success", false)):
		queue_free()
		return
	var flags := threat.flags_for(outcome)
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("has_flag") and flags.size() > 0 \
			and bool(gs.call("has_flag", flags[0])):
		queue_free()
