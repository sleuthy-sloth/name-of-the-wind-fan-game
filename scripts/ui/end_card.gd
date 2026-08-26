class_name EndCard
extends Control

const CONTINUE_SCENE := "res://scenes/world/caravan_route.tscn"
## First continue after the slice starts the post-slice epilogue (ruined camp
## -> Tarbean road); once the epilogue is complete, continue loops to Act I.
const POST_SLICE_SCENE := "res://scenes/world/solo_forest.tscn"
const POST_SLICE_DONE_FLAG := "act1_post_slice_completed"

@onready var _title_label: Label = get_node_or_null("TitleLabel")
@onready var _subtitle_label: Label = get_node_or_null("SubtitleLabel")
@onready var _continue_button: Button = get_node_or_null("ContinueButton")

func _ready() -> void:
	_set_flag("vertical_slice_completed")
	if _title_label != null:
		_title_label.text = "The Name of the Wind"
	if _subtitle_label != null:
		_subtitle_label.text = (
			"Act I closes in smoke and silence. Tarbean waits."
			if _has_flag(POST_SLICE_DONE_FLAG)
			else "The road ahead is long, and the story has only just begun."
		)
	if _continue_button != null:
		_continue_button.pressed.connect(_on_continue_pressed)
	AudioLibrary.play("MUS_STING_ENDCARD", -6.0)

func _set_flag(flag_id: String) -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		gs.set_flag(flag_id)

func _has_flag(flag_id: String) -> bool:
	var gs := get_node_or_null("/root/GameState")
	return gs != null and gs.has_method("has_flag") and bool(gs.call("has_flag", flag_id))

func continue_target() -> String:
	return POST_SLICE_SCENE if not _has_flag(POST_SLICE_DONE_FLAG) else CONTINUE_SCENE

func _on_continue_pressed() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router != null:
		router.change_scene(continue_target())

func simulate_continue() -> void:
	_on_continue_pressed()
