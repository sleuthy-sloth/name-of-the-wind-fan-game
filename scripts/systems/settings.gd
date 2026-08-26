extends Node

## Settings
# Central accessibility + audio preference store. Owns the audio bus topology
# (Music / Ambience / SFX / Master) so the settings menu can set per-category
# volume without poking AudioServer directly. Participates in the save system
# as a save_contributor so a player's accessibility and volume choices
# survive a reload. Autoload singleton — no class_name so it doesn't shadow
# the autoload name.

signal setting_changed(key: String)

const GROUP := "settings"

const DEFAULT_VOLUME_DB := 0.0
const DEFAULT_FONT_SCALE_INDEX := 0

## Boundaries + scale options live on the instance so callers can read them
## through /root/Settings without needing a class_name identifier.
var min_volume_db: float = -40.0
var max_volume_db: float = 6.0
var font_scale_options: Array = [1.0, 1.12, 1.25, 1.5]

var music_volume_db: float = DEFAULT_VOLUME_DB
var ambience_volume_db: float = DEFAULT_VOLUME_DB
var sfx_volume_db: float = DEFAULT_VOLUME_DB
var master_volume_db: float = DEFAULT_VOLUME_DB
var colorblind_mode: bool = false
var reduce_motion: bool = false
var font_scale_index: int = DEFAULT_FONT_SCALE_INDEX

func _ready() -> void:
	add_to_group(GROUP)
	add_to_group("save_contributors")
	_ensure_buses()
	apply_audio_volumes()

## Save system key. Stable identifier so saves survive rename.
func save_state_id() -> String:
	return "settings"

# --- bus topology --------------------------------------------------------------

func _ensure_buses() -> void:
	for bus_name in ["Music", "Ambience", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var index := AudioServer.bus_count
			AudioServer.add_bus()
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")

## Map a logical event id to its audio bus. Pure — no AudioServer calls.
static func bus_for(event_id: String) -> String:
	if event_id.begins_with("MUS_"):
		return "Music"
	if event_id.begins_with("AMB_"):
		return "Ambience"
	if event_id.begins_with("SFX_") or event_id.begins_with("INSTR_"):
		return "SFX"
	return "Master"

# --- mutation -----------------------------------------------------------------

func set_music_volume(value: float) -> void:
	music_volume_db = clampf(value, min_volume_db, max_volume_db)
	apply_audio_volumes()
	setting_changed.emit("music_volume_db")

func set_ambience_volume(value: float) -> void:
	ambience_volume_db = clampf(value, min_volume_db, max_volume_db)
	apply_audio_volumes()
	setting_changed.emit("ambience_volume_db")

func set_sfx_volume(value: float) -> void:
	sfx_volume_db = clampf(value, min_volume_db, max_volume_db)
	apply_audio_volumes()
	setting_changed.emit("sfx_volume_db")

func set_master_volume(value: float) -> void:
	master_volume_db = clampf(value, min_volume_db, max_volume_db)
	apply_audio_volumes()
	setting_changed.emit("master_volume_db")

func set_colorblind_mode(value: bool) -> void:
	colorblind_mode = value
	setting_changed.emit("colorblind_mode")

func set_reduce_motion(value: bool) -> void:
	reduce_motion = value
	setting_changed.emit("reduce_motion")

func set_font_scale_index(value: int) -> void:
	font_scale_index = clampi(value, 0, font_scale_options.size() - 1)
	setting_changed.emit("font_scale_index")

func font_scale() -> float:
	return font_scale_options[font_scale_index] if font_scale_index >= 0 and font_scale_index < font_scale_options.size() else 1.0

func apply_audio_volumes() -> void:
	_apply_bus("Master", master_volume_db)
	_apply_bus("Music", music_volume_db)
	_apply_bus("Ambience", ambience_volume_db)
	_apply_bus("SFX", sfx_volume_db)

func _apply_bus(bus_name: String, value_db: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, value_db)

## Color the threat panel / sympathy markers should use. Colorblind-safe
## palette swaps red ↔ blue and amber ↔ cyan.
func colorblind_adjusted(base: Color) -> Color:
	if not colorblind_mode:
		return base
	var r := base.r
	var g := base.g
	var b := base.b
	var a := base.a
	# If red dominates, push toward blue; if amber/orange dominates, push toward cyan.
	if r > b and r > 0.4:
		return Color(b, g * 0.85, r, a)
	if r > 0.5 and g > 0.3 and b < 0.3:
		return Color(b, g, r, a)
	return base

# --- save / load --------------------------------------------------------------

func collect_save_state() -> Dictionary:
	return {
		"music_volume_db": music_volume_db,
		"ambience_volume_db": ambience_volume_db,
		"sfx_volume_db": sfx_volume_db,
		"master_volume_db": master_volume_db,
		"colorblind_mode": colorblind_mode,
		"reduce_motion": reduce_motion,
		"font_scale_index": font_scale_index,
	}

func apply_save_state(state: Dictionary) -> void:
	music_volume_db = float(state.get("music_volume_db", DEFAULT_VOLUME_DB))
	ambience_volume_db = float(state.get("ambience_volume_db", DEFAULT_VOLUME_DB))
	sfx_volume_db = float(state.get("sfx_volume_db", DEFAULT_VOLUME_DB))
	master_volume_db = float(state.get("master_volume_db", DEFAULT_VOLUME_DB))
	colorblind_mode = bool(state.get("colorblind_mode", false))
	reduce_motion = bool(state.get("reduce_motion", false))
	font_scale_index = int(state.get("font_scale_index", DEFAULT_FONT_SCALE_INDEX))
	apply_audio_volumes()
	setting_changed.emit("loaded")
