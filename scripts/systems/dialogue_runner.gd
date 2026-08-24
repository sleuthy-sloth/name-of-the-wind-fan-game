class_name DialogueRunner
extends CanvasLayer

signal dialogue_finished(dialogue_id: String)

var _data: Dictionary = {}
var _current_node_id: String = ""

var _panel: Panel
var _speaker_label: Label
var _text_label: RichTextLabel
var _choices_box: VBoxContainer

func _ready() -> void:
	layer = 90
	_build_ui()
	hide_ui()

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -160.0
	_panel.offset_bottom = 0.0
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	_speaker_label = Label.new()
	_speaker_label.text = ""
	_speaker_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_speaker_label)

	_text_label = RichTextLabel.new()
	_text_label.text = ""
	_text_label.fit_content = true
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_text_label)

	_choices_box = VBoxContainer.new()
	_choices_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_choices_box)

func start(data: Dictionary) -> void:
	_data = data
	show_ui()
	_show_node(data.get("root", ""))

func get_current_id() -> String:
	return _current_node_id

func hide_ui() -> void:
	_panel.visible = false

func show_ui() -> void:
	_panel.visible = true

func _show_node(id: String) -> void:
	_current_node_id = id
	var nodes: Dictionary = _data.get("nodes", {})
	if not nodes.has(id):
		push_warning("DialogueRunner: unknown node id '%s'" % id)
		hide_ui()
		dialogue_finished.emit(_data.get("dialogue_id", ""))
		return

	var node: Dictionary = nodes[id]
	if node.get("end", false):
		hide_ui()
		dialogue_finished.emit(_data.get("dialogue_id", ""))
		return

	_speaker_label.text = node.get("speaker", "")
	_text_label.text = node.get("text", "")

	for child in _choices_box.get_children():
		child.queue_free()

	var choices: Array = node.get("choices", [])
	if choices.is_empty() and node.has("next"):
		var auto_button := Button.new()
		auto_button.text = "Continue"
		auto_button.pressed.connect(_on_choice.bind(0))
		_choices_box.add_child(auto_button)
	else:
		for index in range(choices.size()):
			var choice: Dictionary = choices[index]
			var button := Button.new()
			button.text = choice.get("text", "...")
			button.pressed.connect(_on_choice.bind(index))
			_choices_box.add_child(button)

func _on_choice(index: int) -> void:
	var nodes: Dictionary = _data.get("nodes", {})
	if not nodes.has(_current_node_id):
		return

	var node: Dictionary = nodes[_current_node_id]
	var choices: Array = node.get("choices", [])
	var next_id: String = ""
	var effects: Array = []

	if choices.is_empty() and node.has("next"):
		next_id = node.get("next", "")
		effects = node.get("effects", [])
	elif index >= 0 and index < choices.size():
		var choice: Dictionary = choices[index]
		next_id = choice.get("next", "")
		effects = choice.get("effects", [])
	else:
		return

	_apply_effects(effects)

	if next_id.is_empty():
		hide_ui()
		dialogue_finished.emit(_data.get("dialogue_id", ""))
	else:
		_show_node(next_id)

func _apply_effects(effects: Array) -> void:
	var gs := _gs()
	if gs == null:
		return

	for entry in effects:
		if not entry is Dictionary:
			continue
		var effect: Dictionary = entry
		var type: String = effect.get("type", "")
		match type:
			"relationship":
				var target: String = effect.get("target", "")
				var delta: float = effect.get("delta", 0.0)
				if not target.is_empty():
					var current: float = gs.relationships.get(target, 0.0)
					gs.relationships[target] = current + delta
			"set_flag":
				var flag: String = effect.get("flag", "")
				if not flag.is_empty():
					gs.set_flag(flag)

func _gs() -> Node:
	return get_node_or_null("/root/GameState")

static func validate(data: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []

	if not data.has("root"):
		errors.append("missing 'root' field")
		return errors

	var root_id: String = data.get("root", "")
	var nodes: Dictionary = data.get("nodes", {})

	if root_id.is_empty():
		errors.append("'root' is empty")

	if nodes.is_empty():
		errors.append("'nodes' is empty")

	if not root_id.is_empty() and not nodes.has(root_id):
		errors.append("root node '%s' not found in nodes" % root_id)

	for node_id in nodes.keys():
		var node: Dictionary = nodes[node_id]
		var is_end: bool = node.get("end", false)

		if not is_end:
			var text: String = node.get("text", "")
			if text.is_empty():
				errors.append("node '%s' has empty text on non-end node" % node_id)

		if node.has("next"):
			var next_id: String = node.get("next", "")
			if not next_id.is_empty() and not nodes.has(next_id):
				errors.append("node '%s' references unknown next node '%s'" % [node_id, next_id])

		var choices: Array = node.get("choices", [])
		for index in range(choices.size()):
			var choice = choices[index]
			if not choice is Dictionary:
				errors.append("node '%s' choice[%d] is not a dictionary" % [node_id, index])
				continue
			var choice_dict: Dictionary = choice
			if choice_dict.has("next"):
				var choice_next: String = choice_dict.get("next", "")
				if not choice_next.is_empty() and not nodes.has(choice_next):
					errors.append("node '%s' choice[%d] references unknown next node '%s'" % [node_id, index, choice_next])

		var effects: Array = node.get("effects", [])
		for index in range(effects.size()):
			var entry = effects[index]
			if not entry is Dictionary:
				errors.append("node '%s' effect[%d] is not a dictionary" % [node_id, index])
				continue
			var effect: Dictionary = entry
			if not effect.has("type"):
				errors.append("node '%s' effect[%d] missing 'type'" % [node_id, index])
				continue
			var type: String = effect.get("type", "")
			match type:
				"relationship":
					if not effect.has("target"):
						errors.append("node '%s' effect[%d] relationship missing 'target'" % [node_id, index])
				"set_flag":
					if not effect.has("flag"):
						errors.append("node '%s' effect[%d] set_flag missing 'flag'" % [node_id, index])

	return errors
