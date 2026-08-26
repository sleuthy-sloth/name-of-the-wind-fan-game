class_name JournalScreen
extends Control

## JournalScreen
# Chronicler's three-tab journal: Story (auto-written entries), Map (visited
# scenes + edges with fog of war), Items (inventory snapshot). Toggle with
# the `journal` action (J key by default).

const PREVIEW_TAB_IDX := 0

static func get_or(d: Dictionary, key: String, default_value: Variant) -> Variant:
	return default_value if not d.has(key) else d[key]

signal closed

@onready var _title_label: Label = get_node_or_null("TitleLabel")
@onready var _story_button: Button = get_node_or_null("TabRow/StoryTabButton")
@onready var _map_button: Button = get_node_or_null("TabRow/MapTabButton")
@onready var _items_button: Button = get_node_or_null("TabRow/ItemsTabButton")
@onready var _story_label: RichTextLabel = get_node_or_null("StoryLabel")
@onready var _map_canvas: Control = get_node_or_null("MapCanvas")
@onready var _items_label: RichTextLabel = get_node_or_null("ItemsLabel")
@onready var _close_button: Button = get_node_or_null("CloseButton")
@onready var _summary_label: Label = get_node_or_null("SummaryLabel")

var _tab: int = 0
var _map_renderer: MapRenderer = null

func _ready() -> void:
	if _close_button != null:
		_close_button.pressed.connect(_on_close)
	if _story_button != null:
		_story_button.pressed.connect(_on_story_tab)
	if _map_button != null:
		_map_button.pressed.connect(_on_map_tab)
	if _items_button != null:
		_items_button.pressed.connect(_on_items_tab)
	_style_title()
	_apply_font_scale()
	_show_tab(PREVIEW_TAB_IDX)

func _style_title() -> void:
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", 32)
		_title_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.7))

func open() -> void:
	visible = true
	if has_focus():
		pass
	_apply_font_scale()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()

func _on_close() -> void:
	AudioLibrary.play("SFX_UI_BACK", -8.0)
	visible = false
	closed.emit()

func _on_story_tab() -> void:
	_tab = 0
	_show_tab(0)

func _on_map_tab() -> void:
	_tab = 1
	_show_tab(1)

func _on_items_tab() -> void:
	_tab = 2
	_show_tab(2)

func _show_tab(index: int) -> void:
	_show_story(index == 0)
	_show_map(index == 1)
	_show_items(index == 2)

# --- tabs --------------------------------------------------------------------

func _show_story(active: bool) -> void:
	_story_label.visible = active
	if not active:
		return
	var journal := get_node_or_null("/root/ChroniclerJournal")
	if journal == null:
		_story_label.text = ""
		return
	var entries: Array = journal.list_entries()
	if entries.is_empty():
		_story_label.text = "[center][i]The journal is empty — write your story.[/i][/center]"
		_summary_label.text = "0 entries"
		return
	var blocks: Array = []
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = (entries as Array)[i]
		var act_day := str(get_or(e, "act", 1)) + "·" + str(get_or(e, "day", 1))
		blocks.append("[b]%s[/b]   [color=#a89070][i]Act %s[/i][/color]\n%s"
			% [str(get_or(e, "heading", "")), act_day, str(get_or(e, "body", ""))])
	_story_label.bbcode_enabled = true
	_story_label.text = "\n\n".join(blocks)
	_summary_label.text = "%d entries" % entries.size()

func _show_map(active: bool) -> void:
	_map_canvas.visible = active
	if not active:
		return
	_map_canvas.queue_redraw()

func _show_items(active: bool) -> void:
	if _items_label == null:
		return
	_items_label.visible = active
	if not active:
		return
	var inventory := Inventory.new()
	var defs: Dictionary = inventory.get_all_definitions()
	if defs.is_empty():
		_items_label.text = "[center][i]No items collected yet.[/i][/center]"
		return
	var lines: Array = []
	for key in defs.keys():
		var defn: Dictionary = defs[key]
		var name: String = str(get_or(defn, "name", key))
		var category: String = str(get_or(defn, "category", ""))
		var count := inventory.count_item(str(key))
		lines.append("[b]%s[/b]  [color=#a89070]%s[/color]  ×%d" % [name, category, count])
	_items_label.bbcode_enabled = true
	_items_label.text = "\n".join(lines)

func _refresh() -> void:
	_show_tab(_tab)

# --- font scale application ---------------------------------------------------

func _apply_font_scale() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return
	var scale: float = settings.font_scale()
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", int(round(32 * scale)))
	if _story_label != null:
		_story_label.add_theme_font_size_override("normal_font_size", int(round(15 * scale)))
	if _items_label != null:
		_items_label.add_theme_font_size_override("normal_font_size", int(round(15 * scale)))
	if _summary_label != null:
		_summary_label.add_theme_font_size_override("font_size", int(round(13 * scale)))

# --- public API for tests -----------------------------------------------------

func refresh_now() -> void:
	_refresh()
