class_name EndCard
extends Control

const CONTINUE_SCENE := "res://scenes/world/caravan_route.tscn"

@onready var _title_label: Label = get_node_or_null("TitleLabel")
@onready var _subtitle_label: Label = get_node_or_null("SubtitleLabel")
@onready var _continue_button: Button = get_node_or_null("ContinueButton")

func _ready() -> void:
	_set_flag("vertical_slice_completed")
	if _title_label != null:
		_title_label.text = "The Name of the Wind"
	if _subtitle_label != null:
		_subtitle_label.text = "The road ahead is long, and the story has only just begun."
	if _continue_button != null:
		_continue_button.pressed.connect(_on_continue_pressed)

func _set_flag(flag_id: String) -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		gs.set_flag(flag_id)

func _on_continue_pressed() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router != null:
		router.change_scene(CONTINUE_SCENE)

func simulate_continue() -> void:
	_on_continue_pressed()
