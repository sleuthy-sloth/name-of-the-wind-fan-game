class_name ThreatPanel
extends CanvasLayer

## ThreatPanel
# In-world presentation for a GDD §7.5 threat encounter. Shows the four
# resolutions (flee routes, hide timing, talk standing, sympathy working),
# live Alar cost/risk preview for the sympathy option, escalating pressure,
# and outcome narration. Emits encounter_finished(outcome) once resolved.

signal encounter_finished(outcome: Dictionary)

const TYPE_FLEE := "flee"
const TYPE_HIDE := "hide"
const TYPE_TALK := "talk"
const TYPE_SYMPATHY := "sympathy"

var _threat: ThreatEncounter = null
var _holder: Object = null
var _last_outcome: Dictionary = {}

var _root: Control = null
var _title: Label = null
var _intro: RichTextLabel = null
var _pressure_label: Label = null
var _outcome: RichTextLabel = null
var _choices: VBoxContainer = null
var _continue_button: Button = null
var _route_buttons: Array[Button] = []

func _ready() -> void:
	layer = 60
	_build_ui()
	visible = false

## Opens the panel for a prepared threat and a GameState-like holder.
func open_for(threat: ThreatEncounter, holder: Object) -> void:
	_threat = threat
	_holder = holder
	_last_outcome = {}
	_populate()
	visible = true
	AudioLibrary.play("SFX_UI_OPEN", -8.0)

func close() -> void:
	visible = false
	_threat = null

func is_open() -> bool:
	return visible

func get_last_outcome() -> Dictionary:
	return _last_outcome

# --- population ---------------------------------------------------------------

func _populate() -> void:
	if _threat == null:
		return
	_title.text = _threat.get_title()
	_intro.text = _threat.get_intro()
	_outcome.text = ""
	_continue_button.visible = false
	_refresh()

func _refresh() -> void:
	if _threat == null:
		return
	var filled := mini(_threat.pressure, 6)
	var dots := ""
	for i in range(filled):
		dots += "●"
	for j in range(maxi(_threat.pressure_limit() - filled, 0)):
		dots += "○"
	_pressure_label.text = "Trouble: " + dots
	_rebuild_choices()
	_refresh_outcome()

func _rebuild_choices() -> void:
	for child in _choices.get_children():
		child.queue_free()
	_route_buttons.clear()
	if not _threat.is_active():
		return

	var def := _threat.def

	if def.has("flee"):
		var flee_btn := _make_choice("Flee — find another way around")
		flee_btn.pressed.connect(func() -> void: _toggle_routes())
		_choices.add_child(flee_btn)
		for i in range(_threat.flee_routes().size()):
			var route := _threat.flee_routes()[i]
			var route_btn := Button.new()
			route_btn.text = "   ↳ " + str(route.get("label", "Route"))
			route_btn.visible = false
			route_btn.pressed.connect(_attempt.bind(TYPE_FLEE, {"route_index": i}))
			_choices.add_child(route_btn)
			_route_buttons.append(route_btn)

	if def.has("hide"):
		var window := _threat.hide_window()
		var hide_btn := _make_choice("Hide — wait for your moment (%d–%d)" % [
			int((window.x - window.y * 0.5) * 100.0), int((window.x + window.y * 0.5) * 100.0)])
		hide_btn.pressed.connect(
			func() -> void: _attempt(TYPE_HIDE, {"timing": randf()})
		)
		_choices.add_child(hide_btn)

	if def.has("talk"):
		var req := _threat.talk_requirement()
		var available := _threat.talk_available(_holder)
		var hint := ""
		match str(req.get("kind", "none")):
			"relationship":
				hint = " (needs %s's trust ≥ %.0f)" % [str(req.get("target", "")), float(req.get("value", 0.0))]
			"reputation":
				hint = " (needs %s repute ≥ %d)" % [str(req.get("group", "")), int(req.get("value", 0))]
		var talk_btn := _make_choice("Talk" + (" ✓" if available else "") + hint)
		talk_btn.pressed.connect(func() -> void: _attempt(TYPE_TALK, {}))
		_choices.add_child(talk_btn)

	if def.has("sympathy"):
		var binding := _threat.sympathy_binding()
		var effect_label := str(binding.get("effect", {}).get("label", "Sympathy"))
		var preview := _threat.sympathy_preview()
		var text := "Sympathy — %s (Cost: %.1f Alar, Risk: %.0f%%)" % [
			effect_label,
			float(preview.get("cost", 0.0)),
			float(preview.get("risk", 0.0)) * 100.0,
		]
		var sym_btn := _make_choice(text)
		sym_btn.pressed.connect(func() -> void: _attempt(TYPE_SYMPATHY, {}))
		_choices.add_child(sym_btn)

func _make_choice(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return button

func _toggle_routes() -> void:
	for button in _route_buttons:
		button.visible = not button.visible

# --- attempts -----------------------------------------------------------------

func _attempt(type: String, payload: Dictionary) -> void:
	if _threat == null or not _threat.is_active():
		return
	AudioLibrary.play("SFX_UI_SELECT", -8.0)
	_last_outcome = _threat.attempt(type, payload, _holder)

	if _threat.is_resolved():
		var gs: Node = Engine.get_main_loop().root.get_node_or_null("GameState")
		if gs != null and gs.has_method("set_flag"):
			for flag in _threat.flags_for(_last_outcome):
				gs.call("set_flag", flag)
	_encounter_finished_check()
	_refresh()

func _encounter_finished_check() -> void:
	if _threat != null and _threat.is_resolved():
		AudioLibrary.play("SFX_UI_NOTIFICATION", -6.0)
		_continue_button.visible = true

func _refresh_outcome() -> void:
	if _last_outcome.has("text") and not str(_last_outcome["text"]).is_empty():
		var prefix := "" if bool(_last_outcome.get("success", false)) else "[color=#d98a7a]"
		var suffix := "" if bool(_last_outcome.get("success", false)) else "[/color]"
		_outcome.text = prefix + str(_last_outcome["text"]) + suffix

func _on_continue() -> void:
	if _threat == null or not _threat.is_resolved():
		return
	var outcome := _last_outcome
	close()
	encounter_finished.emit(outcome)

# --- UI construction ----------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var tint := ColorRect.new()
	tint.name = "BackgroundTint"
	tint.color = Color(0.07, 0.04, 0.04, 0.9)
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(tint)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.custom_minimum_size = Vector2(620, 0)
	margin.add_child(vbox)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(_title)

	_pressure_label = Label.new()
	_pressure_label.add_theme_color_override("font_color", Color(0.85, 0.55, 0.45))
	vbox.add_child(_pressure_label)

	_intro = RichTextLabel.new()
	_intro.fit_content = true
	_intro.bbcode_enabled = true
	_intro.custom_minimum_size = Vector2(620, 56)
	vbox.add_child(_intro)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	vbox.add_child(_choices)

	_outcome = RichTextLabel.new()
	_outcome.fit_content = true
	_outcome.bbcode_enabled = true
	_outcome.custom_minimum_size = Vector2(620, 48)
	vbox.add_child(_outcome)

	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.visible = false
	_continue_button.pressed.connect(_on_continue)
	vbox.add_child(_continue_button)
