class_name TitleMenu
extends Control

## TitleMenu
# The front door of the game. Three buttons: New Game (reset state and play
# the Waystone opening), Continue (load slot 0 if a save exists and drop the
# player into the saved scene), and Quit. Visual style matches the warm
# parchment aesthetic of the slice; ambient fire loop ties it to the inn.

const NEW_GAME_SCENE := "res://scenes/world/waystone_inn.tscn"
const SAVE_SLOT := 0
const HOLD_AGE_MS := 600

@onready var _title_label: Label = get_node_or_null("TitleLabel")
@onready var _subtitle_label: Label = get_node_or_null("SubtitleLabel")
@onready var _byline_label: Label = get_node_or_null("BylineLabel")
@onready var _new_button: Button = get_node_or_null("Buttons/NewGameButton")
@onready var _continue_button: Button = get_node_or_null("Buttons/ContinueButton")
@onready var _quit_button: Button = get_node_or_null("Buttons/QuitButton")
@onready var _fade_rect: ColorRect = get_node_or_null("FadeRect")

var _hold_timer: Timer = null

func _ready() -> void:
	_play_ambience()
	_style_labels()
	_wire_buttons()
	_apply_continue_state()
	_play_fade_in()
	_apply_input_map()

func _apply_input_map() -> void:
	# Make sure the input map used by UI buttons (ui_accept / ui_cancel /
	# ui_up / ui_down) is present — Godot ships them by default but tests
	# sometimes run with a minimal map; we don't override anything here.
	pass

func _play_ambience() -> void:
	var stream := AudioLibrary.stream_for("AMB_FIRE_SMALL")
	if stream is AudioStream:
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		var player := AudioStreamPlayer.new()
		player.name = "AmbiencePlayer"
		player.stream = stream
		player.volume_db = -10.0
		player.autoplay = true
		add_child(player)

func _style_labels() -> void:
	if _title_label != null:
		_title_label.text = "The Name of the Wind"
		_title_label.add_theme_font_size_override("font_size", 54)
		_title_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.7))
		_title_label.add_theme_color_override("font_shadow_color", Color(0.04, 0.02, 0.0, 0.85))
		_title_label.add_theme_constant_override("shadow_offset_x", 3)
		_title_label.add_theme_constant_override("shadow_offset_y", 3)
	if _subtitle_label != null:
		_subtitle_label.text = "The Kingkiller Chronicle — an unofficial fan game"
		_subtitle_label.add_theme_font_size_override("font_size", 16)
		_subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.7, 0.55))
	if _byline_label != null:
		_byline_label.text = "In the world we make, words are the most honest tools we have."
		_byline_label.add_theme_font_size_override("font_size", 12)
		_byline_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.38))

func _wire_buttons() -> void:
	if _new_button != null:
		_new_button.pressed.connect(_on_new_game)
	if _continue_button != null:
		_continue_button.pressed.connect(_on_continue)
	if _quit_button != null:
		_quit_button.pressed.connect(_on_quit)

func _apply_continue_state() -> void:
	if _continue_button == null:
		return
	var save_manager := get_node_or_null("/root/SaveManager")
	var has_save := false
	if save_manager != null and save_manager.has_method("has_save"):
		has_save = bool(save_manager.call("has_save", SAVE_SLOT))
	_continue_button.disabled = not has_save
	if not has_save:
		_continue_button.text = "Continue (no save)"

func _play_fade_in() -> void:
	if _fade_rect == null:
		return
	_fade_rect.modulate.a = 1.0
	var tween := create_tween()
	if tween != null:
		tween.tween_property(_fade_rect, "modulate:a", 0.0, 0.6)

## Public for tests: true when slot 0 holds a usable save.
func has_continue_save() -> bool:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null or not save_manager.has_method("has_save"):
		return false
	return bool(save_manager.call("has_save", SAVE_SLOT))

func _on_new_game() -> void:
	AudioLibrary.play("SFX_UI_CONFIRM", -4.0)
	_reset_world()
	_route_to(NEW_GAME_SCENE)

func _on_continue() -> void:
	AudioLibrary.play("SFX_UI_CONFIRM", -4.0)
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null or not save_manager.has_method("load_game"):
		return
	if not bool(save_manager.call("load_game", SAVE_SLOT)):
		return
	_route_to(_scene_from_save())

func _on_quit() -> void:
	AudioLibrary.play("SFX_UI_CONFIRM", -4.0)
	get_tree().quit()

## Reset GameState to a clean Act I start and remove the save slot so the
## game truly begins fresh.
func _reset_world() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var fresh_gs: Node = load("res://scripts/systems/game_state.gd").new()
	gs.from_dict(fresh_gs.to_dict())
	fresh_gs.queue_free()
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null and save_manager.has_method("delete_save"):
		save_manager.call("delete_save", SAVE_SLOT)

func _scene_from_save() -> String:
	# SaveManager doesn't expose scene_path directly; peek the slot file.
	var path := "user://saves/slot_%d.json" % SAVE_SLOT
	if not FileAccess.file_exists(path):
		return NEW_GAME_SCENE
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var scene: Variant = (parsed as Dictionary).get("scene_path", "")
		if scene is String and not (scene as String).is_empty():
			return scene as String
	return NEW_GAME_SCENE

func _route_to(scene_path: String) -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router != null and router.has_method("change_scene"):
		router.call("change_scene", scene_path)
