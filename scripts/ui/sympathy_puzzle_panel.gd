class_name SympathyPuzzlePanel
extends CanvasLayer

## SympathyPuzzlePanel
# In-world presentation for an out-of-combat sympathy working. Shows the
# puzzle prompt, the player's source choice (the only free slot — link,
# target, and effect are pinned by the puzzle), a live Alar cost/risk
# preview, and confirm/cancel. Emits resolved(outcome) or cancelled.

signal resolved(outcome: Dictionary)
signal cancelled

var _puzzle: SympathyPuzzle = null
var _alar_holder: Object = null
var _journal: Journal = null

var _root: Control = null
var _title: Label = null
var _prompt: RichTextLabel = null
var _source_picker: OptionButton = null
var _cost_label: Label = null
var _risk_label: Label = null
var _confirm: Button = null
var _cancel: Button = null

func _ready() -> void:
	layer = 60
	_build_ui()
	visible = false

## Opens the panel for a prepared puzzle and alar holder.
func open_for(puzzle: SympathyPuzzle, alar_holder: Object) -> void:
	_puzzle = puzzle
	_alar_holder = alar_holder
	_populate()
	visible = true
	AudioLibrary.play("SFX_UI_OPEN", -8.0)

func close() -> void:
	visible = false
	_puzzle = null

func is_open() -> bool:
	return visible

func _populate() -> void:
	if _puzzle == null:
		return
	var def := _puzzle.def
	_title.text = str(def.get("title", "Sympathy Working"))
	_prompt.text = str(def.get("prompt", ""))
	_source_picker.clear()
	for s in _puzzle.sources():
		_source_picker.add_item(str(s.get("label", s.get("id", "?"))))
	if _puzzle.sources().size() > 0:
		_source_picker.select(0)
	_refresh_preview()

func _refresh_preview() -> void:
	if _puzzle == null:
		return
	var p := _puzzle.preview()
	_cost_label.text = "Cost: %.1f Alar" % float(p.get("cost", 0.0))
	var risk := float(p.get("risk", 0.0)) * 100.0
	_risk_label.text = "Risk: %.0f%%" % risk
	_confirm.disabled = not bool(p.get("valid", false))

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var tint := ColorRect.new()
	tint.name = "BackgroundTint"
	tint.color = Color(0.04, 0.05, 0.09, 0.9)
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
	vbox.add_theme_constant_override("separation", 14)
	vbox.custom_minimum_size = Vector2(560, 0)
	margin.add_child(vbox)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)

	_prompt = RichTextLabel.new()
	_prompt.fit_content = true
	_prompt.bbcode_enabled = true
	_prompt.custom_minimum_size = Vector2(560, 64)
	vbox.add_child(_prompt)

	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(slots)
	slots.add_child(_make_slot_label("SOURCE"))

	_source_picker = OptionButton.new()
	_source_picker.item_selected.connect(_on_source_selected)
	slots.add_child(_source_picker)

	var preview_row := HBoxContainer.new()
	preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_row.add_theme_constant_override("separation", 40)
	vbox.add_child(preview_row)
	_cost_label = Label.new()
	_risk_label = Label.new()
	preview_row.add_child(_cost_label)
	preview_row.add_child(_risk_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	vbox.add_child(buttons)

	_confirm = Button.new()
	_confirm.text = "Bind"
	_confirm.pressed.connect(_on_confirm)
	buttons.add_child(_confirm)

	_cancel = Button.new()
	_cancel.text = "Step back"
	_cancel.pressed.connect(_on_cancel)
	buttons.add_child(_cancel)

func _make_slot_label(text: String) -> Label:
	var label := Label.new()
	label.text = text + ": "
	label.add_theme_font_size_override("font_size", 16)
	return label

func _on_source_selected(index: int) -> void:
	if _puzzle != null:
		_puzzle.select_source(index)
		_refresh_preview()

func _on_confirm() -> void:
	if _puzzle == null or _alar_holder == null:
		return
	var outcome := _puzzle.commit(_alar_holder)
	_record_in_journal(outcome)
	close()
	resolved.emit(outcome)

## Mirrors the bench behavior: every committed working lands in the journal.
func _record_in_journal(outcome: Dictionary) -> void:
	if _journal == null:
		_journal = Journal.new()
	_journal.add_entry(
		str(outcome.get("source_id", "")),
		str(outcome.get("link_id", "")),
		str(outcome.get("target_id", "")),
		str(outcome.get("effect_id", "")),
		"success" if bool(outcome.get("success", false)) else str(outcome.get("failure_consequence", "failure"))
	)

func get_journal() -> Journal:
	return _journal

func _on_cancel() -> void:
	close()
	cancelled.emit()
