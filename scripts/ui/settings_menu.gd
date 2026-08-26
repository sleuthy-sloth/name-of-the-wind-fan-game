class_name SettingsMenu
extends Control

## SettingsMenu
# Player-facing preferences panel. Volume sliders for Music / Ambience / SFX,
# a Master cap, accessibility toggles (colorblind palette, reduce motion,
# font scale). All values persist via Settings autoload which doubles as a
# save_contributor. Opened from the title menu and the end card.

const PREVIEW_LABEL_BASE_SIZE := 14
const PREVIEW_SAMPLE := "In the world we make, words are the most honest tools we have."

@onready var _title_label: Label = get_node_or_null("TitleLabel")
@onready var _master_slider: HSlider = get_node_or_null("Volume/MasterRow/Slider")
@onready var _master_value: Label = get_node_or_null("Volume/MasterRow/Value")
@onready var _music_slider: HSlider = get_node_or_null("Volume/MusicRow/Slider")
@onready var _music_value: Label = get_node_or_null("Volume/MusicRow/Value")
@onready var _ambience_slider: HSlider = get_node_or_null("Volume/AmbienceRow/Slider")
@onready var _ambience_value: Label = get_node_or_null("Volume/AmbienceRow/Value")
@onready var _sfx_slider: HSlider = get_node_or_null("Volume/SFXRow/Slider")
@onready var _sfx_value: Label = get_node_or_null("Volume/SFXRow/Value")
@onready var _colorblind_toggle: CheckButton = get_node_or_null("Accessibility/ColorblindToggle")
@onready var _reduce_motion_toggle: CheckButton = get_node_or_null("Accessibility/ReduceMotionToggle")
@onready var _font_scale_smaller: Button = get_node_or_null("Accessibility/FontScaleRow/Smaller")
@onready var _font_scale_larger: Button = get_node_or_null("Accessibility/FontScaleRow/Larger")
@onready var _font_scale_value: Label = get_node_or_null("Accessibility/FontScaleRow/Value")
@onready var _preview_label: Label = get_node_or_null("Accessibility/PreviewLabel")
@onready var _back_button: Button = get_node_or_null("BackButton")

var _settings: Settings = null

func _ready() -> void:
	_settings = get_node_or_null("/root/Settings")
	_style_labels()
	_wire_signals()
	_refresh()

func _style_labels() -> void:
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", 36)
		_title_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.7))
		var headers: Array = []
		for node in get_tree().get_nodes_in_group("") if false else []:
			pass
		# Big section header under volume section:
		var header := get_node_or_null("Accessibility/Header") as Label
		if header != null:
			header.add_theme_font_size_override("font_size", 22)
			header.add_theme_color_override("font_color", Color(0.96, 0.88, 0.7))
		# Row labels:
		for row_label in ["Volume/MasterRow/Label", "Volume/MusicRow/Label", "Volume/AmbienceRow/Label", "Volume/SFXRow/Label"]:
			var l := get_node_or_null(row_label) as Label
			if l != null:
				l.add_theme_font_size_override("font_size", 18)
		# Value labels under sliders:
		for row_value in ["Volume/MasterRow/Value", "Volume/MusicRow/Value", "Volume/AmbienceRow/Value", "Volume/SFXRow/Value"]:
			var v := get_node_or_null(row_value) as Label
			if v != null:
				v.add_theme_font_size_override("font_size", 14)
		# Accessibility toggle labels:
		for cb in ["ColorblindToggle", "ReduceMotionToggle"]:
			var b := get_node_or_null(cb) as CheckButton
			if b != null:
				b.add_theme_font_size_override("font_size", 16)
		# Font-scale row labels:
		for lr in ["Accessibility/FontScaleRow/Label", "Accessibility/FontScaleRow/Value"]:
			var lbl := get_node_or_null(lr) as Label
			if lbl != null:
				lbl.add_theme_font_size_override("font_size", 16)
		var preview := get_node_or_null("Accessibility/PreviewLabel") as Label
		if preview != null:
			preview.add_theme_font_size_override("font_size", 14)
			preview.add_theme_color_override("font_color", Color(0.78, 0.7, 0.55))

func _wire_signals() -> void:
	if _master_slider != null:
		_master_slider.value_changed.connect(_on_master_changed)
	if _music_slider != null:
		_music_slider.value_changed.connect(_on_music_changed)
	if _ambience_slider != null:
		_ambience_slider.value_changed.connect(_on_ambience_changed)
	if _sfx_slider != null:
		_sfx_slider.value_changed.connect(_on_sfx_changed)
	if _colorblind_toggle != null:
		_colorblind_toggle.toggled.connect(_on_colorblind_toggled)
	if _reduce_motion_toggle != null:
		_reduce_motion_toggle.toggled.connect(_on_reduce_motion_toggled)
	if _font_scale_smaller != null:
		_font_scale_smaller.pressed.connect(_on_font_scale_smaller)
	if _font_scale_larger != null:
		_font_scale_larger.pressed.connect(_on_font_scale_larger)
	if _back_button != null:
		_back_button.pressed.connect(_on_back_pressed)
	if _settings != null:
		_settings.setting_changed.connect(_on_settings_changed)

# `n_sliders` is the number of per-category volume sliders (master counts too
# for layout symmetry). Sliders map linear 0..1 to MIN_VOLUME_DB..0 dB so the
# UI feels natural; the AudioServer gets the raw dB value.

func _refresh() -> void:
	if _settings == null:
		return
	if _master_slider != null:
		_master_slider.value = _db_to_slider(_settings.master_volume_db)
	if _music_slider != null:
		_music_slider.value = _db_to_slider(_settings.music_volume_db)
	if _ambience_slider != null:
		_ambience_slider.value = _db_to_slider(_settings.ambience_volume_db)
	if _sfx_slider != null:
		_sfx_slider.value = _db_to_slider(_settings.sfx_volume_db)
	if _colorblind_toggle != null:
		_colorblind_toggle.button_pressed = _settings.colorblind_mode
	if _reduce_motion_toggle != null:
		_reduce_motion_toggle.button_pressed = _settings.reduce_motion
	_update_value_labels()
	_update_font_scale_label()

func _on_master_changed(value: float) -> void:
	if _settings != null:
		_settings.set_master_volume(_slider_to_db(value))
	_update_value_labels()

func _on_music_changed(value: float) -> void:
	if _settings != null:
		_settings.set_music_volume(_slider_to_db(value))
	_update_value_labels()

func _on_ambience_changed(value: float) -> void:
	if _settings != null:
		_settings.set_ambience_volume(_slider_to_db(value))
	_update_value_labels()

func _on_sfx_changed(value: float) -> void:
	if _settings != null:
		_settings.set_sfx_volume(_slider_to_db(value))
	_update_value_labels()

func _on_colorblind_toggled(pressed: bool) -> void:
	if _settings != null:
		_settings.set_colorblind_mode(pressed)

func _on_reduce_motion_toggled(pressed: bool) -> void:
	if _settings != null:
		_settings.set_reduce_motion(pressed)

func _on_font_scale_smaller() -> void:
	if _settings != null:
		_settings.set_font_scale_index(_settings.font_scale_index - 1)

func _on_font_scale_larger() -> void:
	if _settings != null:
		_settings.set_font_scale_index(_settings.font_scale_index + 1)

func _on_settings_changed(_key: String) -> void:
	_refresh()

func _on_back_pressed() -> void:
	AudioLibrary.play("SFX_UI_BACK", -6.0)
	get_tree().change_scene_to_file(_previous_scene_path())

func _previous_scene_path() -> String:
	# When reached from the title menu, the JournalScene / SettingsMenu got
	# popped in as a transient overlay. Save the previous scene to a meta
	# key on the SceneTree root before changing scene.
	var meta := get_tree().root.get_meta("settings_return_scene", "")
	if meta is String and not (meta as String).is_empty():
		return meta
	return "res://scenes/ui/title_menu.tscn"

## Public entry point for callers: opens the menu with a known return path.
func open_with_return(return_scene: String) -> void:
	get_tree().root.set_meta("settings_return_scene", return_scene)

func _update_value_labels() -> void:
	if _settings == null:
		return
	if _master_value != null:
		_master_value.text = "%+.0f dB" % _settings.master_volume_db
	if _music_value != null:
		_music_value.text = "%+.0f dB" % _settings.music_volume_db
	if _ambience_value != null:
		_ambience_value.text = "%+.0f dB" % _settings.ambience_volume_db
	if _sfx_value != null:
		_sfx_value.text = "%+.0f dB" % _settings.sfx_volume_db

func _update_font_scale_label() -> void:
	if _settings == null or _font_scale_value == null or _preview_label == null:
		return
	var scale := _settings.font_scale()
	var pct := int(round(scale * 100.0))
	_font_scale_value.text = "%d%%" % pct
	_preview_label.add_theme_font_size_override("font_size", int(round(PREVIEW_LABEL_BASE_SIZE * scale)))
	if _preview_label.text.is_empty():
		_preview_label.text = PREVIEW_SAMPLE

# Slider 0..1 → dB range [min_volume_db, max_volume_db].
func _slider_to_db(value: float) -> float:
	var settings := _settings
	if settings == null:
		return 0.0
	return clampf(settings.min_volume_db + (0.0 - settings.min_volume_db) * value, settings.min_volume_db, settings.max_volume_db)

func _db_to_slider(db: float) -> float:
	var settings := _settings
	if settings == null:
		return 1.0
	if 0.0 - settings.min_volume_db == 0.0:
		return 1.0
	return clampf((db - settings.min_volume_db) / (0.0 - settings.min_volume_db), 0.0, 1.0)
