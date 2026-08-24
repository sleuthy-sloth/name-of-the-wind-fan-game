## DebugOverlay
# F3-toggled diagnostic HUD showing GameState and current scene.
extends CanvasLayer

var _label: Label

func _ready() -> void:
	layer = 100
	visible = false

	var panel := Panel.new()
	panel.position = Vector2(8, 8)
	add_child(panel)

	_label = Label.new()
	_label.position = Vector2(8, 8)
	add_child(_label)

	var settings := LabelSettings.new()
	settings.font_size = 14
	settings.font_color = Color.WHITE
	settings.outline_size = 1
	settings.outline_color = Color.BLACK
	_label.label_settings = settings

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", style)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.physical_keycode == KEY_F3:
			visible = not visible
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not visible or _label == null:
		return

	var gs = _gs()
	if gs == null:
		_label.text = "GameState not found"
		return

	var scene_name := ""
	if get_tree().current_scene != null:
		scene_name = get_tree().current_scene.name

	_label.text = (
		"Act %d | Day %d | %s\n" +
		"Alar %.0f/%.0f | Money %d\n" +
		"Flags: %d | Scene: %s"
	) % [
		gs.act, gs.day, gs.time_block,
		gs.alar, gs.max_alar, gs.money,
		gs.world_flags.size(), scene_name,
	]

	# Resize panel to fit label plus padding.
	var panel := get_child(0) as Panel
	if panel != null:
		panel.size = _label.get_minimum_size() + Vector2(16, 16)

func _gs() -> Variant:
	var singleton := get_node_or_null("/root/GameState")
	if singleton != null:
		return singleton
	for child in get_tree().root.get_children():
		if child.is_class("Node") and child.get_script() != null:
			if child.get_script().resource_path.ends_with("game_state.gd"):
				return child
	return null
