## SympathyBench
# Three-slot Sympathy workbench UI (GDD §8.4 / §24).
# Displays source/link/target selections, an effect picker, and a pre-commit
# panel with computed cost and risk. Confirm/cancel are wired to a pure
# SympathyEngine so the player sees the stakes before committing.
class_name SympathyBench
extends Control

signal working_committed(result: Dictionary)
signal working_cancelled

@export var alar_holder: Object = null

@onready var source_label: Label = %SourceLabel
@onready var link_label: Label = %LinkLabel
@onready var target_label: Label = %TargetLabel
@onready var effect_picker: OptionButton = %EffectPicker
@onready var cost_label: Label = %CostLabel
@onready var risk_label: Label = %RiskLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton

var engine: SympathyEngine = SympathyEngine.new()
var journal: Journal = Journal.new()

var _available_sources: Array[Dictionary] = []
var _available_links: Array[Dictionary] = []
var _available_targets: Array[Dictionary] = []
var _available_effects: Array[Dictionary] = []

var _selected_source_index: int = -1
var _selected_link_index: int = -1
var _selected_target_index: int = -1

func _ready() -> void:
	if effect_picker != null:
		effect_picker.item_selected.connect(_on_effect_selected)
	if confirm_button != null:
		confirm_button.pressed.connect(_on_confirm)
	if cancel_button != null:
		cancel_button.pressed.connect(_on_cancel)
	_update_preview()

func setup(
	p_alar_holder: Object,
	p_sources: Array[Dictionary],
	p_links: Array[Dictionary],
	p_targets: Array[Dictionary],
	p_effects: Array[Dictionary]
) -> void:
	alar_holder = p_alar_holder
	_available_sources = p_sources
	_available_links = p_links
	_available_targets = p_targets
	_available_effects = p_effects
	_populate_effect_picker()
	_select_defaults()
	_update_display()

func set_source_index(index: int) -> void:
	_selected_source_index = clampi(index, -1, _available_sources.size() - 1)
	_rebuild_engine_binding()
	_update_display()

func set_link_index(index: int) -> void:
	_selected_link_index = clampi(index, -1, _available_links.size() - 1)
	_rebuild_engine_binding()
	_update_display()

func set_target_index(index: int) -> void:
	_selected_target_index = clampi(index, -1, _available_targets.size() - 1)
	_rebuild_engine_binding()
	_update_display()

func get_preview() -> Dictionary:
	return engine.resolve(alar_holder, false)

func _populate_effect_picker() -> void:
	if effect_picker == null:
		return
	effect_picker.clear()
	for effect: Dictionary in _available_effects:
		effect_picker.add_item(effect.get("label", effect.get("id", "?")))
	if _available_effects.size() > 0:
		effect_picker.select(0)
		_on_effect_selected(0)

func _select_defaults() -> void:
	_selected_source_index = 0 if _available_sources.size() > 0 else -1
	_selected_link_index = 0 if _available_links.size() > 0 else -1
	_selected_target_index = 0 if _available_targets.size() > 0 else -1
	_rebuild_engine_binding()

func _rebuild_engine_binding() -> void:
	engine.set_source(_dict_at(_available_sources, _selected_source_index))
	engine.set_link(_dict_at(_available_links, _selected_link_index))
	engine.set_target(_dict_at(_available_targets, _selected_target_index))
	var effect_index := effect_picker.selected if effect_picker != null else -1
	engine.set_effect(_dict_at(_available_effects, effect_index))

func _on_effect_selected(_index: int) -> void:
	_rebuild_engine_binding()
	_update_display()

func _update_display() -> void:
	_update_slot_labels()
	_update_preview()

func _update_slot_labels() -> void:
	if source_label != null:
		source_label.text = _slot_text("SOURCE", _available_sources, _selected_source_index, "id")
	if link_label != null:
		link_label.text = _slot_text("LINK", _available_links, _selected_link_index, "id")
	if target_label != null:
		target_label.text = _slot_text("TARGET", _available_targets, _selected_target_index, "id")

func _update_preview() -> void:
	var preview := get_preview()
	if cost_label != null:
		cost_label.text = "Cost: %.1f Alar" % preview["cost"]
	if risk_label != null:
		var risk_percent: float = preview["risk"] * 100.0
		risk_label.text = "Risk: %.1f%%" % risk_percent
	if confirm_button != null:
		confirm_button.disabled = not _can_commit()

func _can_commit() -> bool:
	return (
		alar_holder != null
		and _selected_source_index >= 0
		and _selected_link_index >= 0
		and _selected_target_index >= 0
		and _available_effects.size() > 0
		and effect_picker != null
		and effect_picker.selected >= 0
	)

func _on_confirm() -> void:
	if not _can_commit():
		return
	var result := engine.resolve(alar_holder, true)
	journal.add_entry(
		result["source_id"],
		result["link_id"],
		result["target_id"],
		result["effect_id"],
		"success" if result["success"] else result.get("failure_consequence", "failure")
	)
	working_committed.emit(result)
	_update_preview()

func _on_cancel() -> void:
	working_cancelled.emit()

func _slot_text(prefix: String, pool: Array[Dictionary], index: int, key: String) -> String:
	if index < 0 or index >= pool.size():
		return "%s: --" % prefix
	var value: Variant = pool[index].get(key, "?")
	return "%s: %s" % [prefix, str(value)]

func _dict_at(pool: Array[Dictionary], index: int) -> Dictionary:
	if index < 0 or index >= pool.size():
		return {}
	return pool[index]
