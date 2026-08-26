class_name CreditsScreen
extends Control

## CreditsScreen
# Scrolling acknowledgements for the vertical slice. Reads the generated
# AUDIO-CREDITS.txt + LPC-CREDITS.txt and stitches them into the on-screen
# RichTextLabel with the project attribution block at the top. Back button
# returns to whichever scene invoked us (defaults to title menu).

const AUDIO_CREDITS_PATH := "res://CREDITS/AUDIO-CREDITS.txt"
const LPC_CREDITS_PATH := "res://CREDITS/LPC-CREDITS.txt"

@onready var _title_label: Label = get_node_or_null("TitleLabel")
@onready var _body_label: RichTextLabel = get_node_or_null("Body")
@onready var _back_button: Button = get_node_or_null("BackButton")

func _ready() -> void:
	if _title_label != null:
		_title_label.text = "Credits"
	_apply_settings()
	_style_body()
	_populate()
	if _back_button != null:
		_back_button.pressed.connect(_on_back_pressed)

func _style_body() -> void:
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", 36)
		_title_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.7))
	if _body_label != null:
		_body_label.add_theme_font_size_override("normal_font_size", 15)
		_body_label.add_theme_color_override("default_color", Color(0.86, 0.78, 0.62))

func _apply_settings() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return
	var scale := settings.font_scale()
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", int(round(36 * scale)))
	if _body_label != null:
		_body_label.add_theme_font_size_override("normal_font_size", int(round(15 * scale)))

func _populate() -> void:
	var sections := [
		_header_block(),
		_section("Audio", _load_text(AUDIO_CREDITS_PATH)),
		_section("Sprite art", _load_text(LPC_CREDITS_PATH)),
	]
	if _body_label != null:
		_body_label.bbcode_enabled = true
		_body_label.text = "\n\n".join(sections)

func _header_block() -> String:
	return (
		"[center][b]The Name of the Wind: The Kingkiller Chronicle[/b][/center]\n"
		+ "[center]An unofficial, non-commercial fan game based on\n"
		+ "The Kingkiller Chronicle by Patrick Rothfuss.[/center]\n"
		+ "[center]Not affiliated with, endorsed by, or authorized by\n"
		+ "Patrick Rothfuss or any rights holder.[/center]\n"
		+ "\n"
		+ "[center]Code: MIT License[/center]\n"
		+ "[center]Art, audio, maps & writing: CC BY-NC-SA 4.0[/center]\n"
		+ "[center]Distributed free of charge.[/center]"
	)

func _section(title: String, body: String) -> String:
	if body.is_empty():
		return "[b]%s[/b]\n[center]No credits on file.[/center]" % title
	return "[b]%s[/b]\n%s" % [title, body]

func _load_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)

func _on_back_pressed() -> void:
	AudioLibrary.play("SFX_UI_BACK", -6.0)
	var meta := get_tree().root.get_meta("credits_return_scene", "")
	var target := meta if meta is String and not (meta as String).is_empty() else "res://scenes/ui/title_menu.tscn"
	get_tree().change_scene_to_file(target)
