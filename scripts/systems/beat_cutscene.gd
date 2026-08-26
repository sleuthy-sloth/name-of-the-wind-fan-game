class_name BeatCutscene
extends Node

## BeatCutscene
# Generic data-driven narration cutscene. Loads a beat list from a JSON file
# ({ "id": ..., "beats": [ {narration, effect, duration, set_flag, sfx,
# next_scene, autosave}, ... ] }) and plays each beat as timed overlay text,
# mirroring the ChandrianAttack presentation. The final beat may route to a
# next scene via SceneRouter. Headless-friendly: no visual node is required;
# when Overlay/NarrationLabel children are missing it still advances beats,
# applies flags, and finishes.

signal sequence_finished(cutscene_id: String)

@export var beats_path: String = ""
@export var auto_start := true

var _beats: Array = []
var _cutscene_id: String = ""
var _current_beat_index: int = -1
var _complete: bool = false
var _started: bool = false
var _overlay: ColorRect = null
var _label: RichTextLabel = null
var _tween: Tween = null

func _ready() -> void:
	_overlay = get_node_or_null("OverlayLayer/Overlay") as ColorRect
	if _overlay == null:
		_overlay = get_node_or_null("Overlay") as ColorRect
	_label = get_node_or_null("TextLayer/NarrationLabel") as RichTextLabel
	if _label == null:
		_label = get_node_or_null("NarrationLabel") as RichTextLabel
	if auto_start:
		call_deferred("start_sequence")

func start_sequence() -> void:
	if _started:
		return
	_started = true
	_complete = false
	_current_beat_index = -1

	if beats_path.is_empty():
		push_error("BeatCutscene: beats_path is empty")
		_complete = true
		return

	var data: Variant = _load_json(beats_path)
	if data == null or not data is Dictionary:
		push_error("BeatCutscene: failed to load beats from %s" % beats_path)
		_complete = true
		return

	var dict: Dictionary = data as Dictionary
	_cutscene_id = dict.get("id", "")
	var raw_beats: Variant = dict.get("beats")
	if raw_beats == null or not raw_beats is Array or (raw_beats as Array).is_empty():
		push_error("BeatCutscene: no 'beats' array in %s" % beats_path)
		_complete = true
		sequence_finished.emit(_cutscene_id)
		return

	_beats = raw_beats as Array
	_advance_beat()

func is_sequence_complete() -> bool:
	return _complete

func get_cutscene_id() -> String:
	return _cutscene_id

func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("BeatCutscene: could not open %s" % path)
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)

func _advance_beat() -> void:
	_current_beat_index += 1
	if _current_beat_index >= _beats.size():
		_complete = true
		sequence_finished.emit(_cutscene_id)
		_route_next()
		return

	var beat: Variant = _beats[_current_beat_index]
	if beat == null or not beat is Dictionary:
		_advance_beat()
		return

	var beat_dict: Dictionary = beat as Dictionary
	_apply_beat(beat_dict)

	var duration: float = beat_dict.get("duration", 1.0)
	if duration <= 0.0:
		duration = 0.01
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(_advance_beat, CONNECT_ONE_SHOT)

func _apply_beat(beat: Dictionary) -> void:
	var text: String = beat.get("narration", "")
	if _label != null:
		_label.text = text

	var sfx: String = beat.get("sfx", "")
	if not sfx.is_empty():
		AudioLibrary.play(sfx, -6.0)

	_apply_effect(str(beat.get("effect", "calm")))

	var flag: String = beat.get("set_flag", "")
	if not flag.is_empty():
		var gs: Node = get_node_or_null("/root/GameState")
		if gs != null and gs.has_method("set_flag"):
			gs.call("set_flag", flag)

	if beat.get("autosave", false) == true:
		var sm: Node = get_node_or_null("/root/SaveManager")
		if sm != null and sm.has_method("save_game"):
			sm.call("save_game", 0)

func _apply_effect(effect: String) -> void:
	if _overlay == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if _tween == null:
		return
	match effect:
		"calm":
			_tween.tween_property(_overlay, "color", Color(0.0, 0.0, 0.0, 0.0), 0.5)
		"unease":
			_tween.tween_property(_overlay, "color", Color(0.15, 0.0, 0.0, 0.25), 0.8)
		"dim":
			_tween.tween_property(_overlay, "color", Color(0.0, 0.0, 0.0, 0.55), 0.8)
		"warm":
			_tween.tween_property(_overlay, "color", Color(0.35, 0.18, 0.02, 0.22), 1.0)
		"darkness":
			_tween.tween_property(_overlay, "color", Color(0.0, 0.0, 0.0, 0.95), 1.5)
		_:
			_tween.tween_property(_overlay, "color", Color(0.0, 0.0, 0.0, 0.0), 0.5)

func _route_next() -> void:
	var next_scene := ""
	if _beats.size() > 0:
		var last: Variant = _beats[_beats.size() - 1]
		if last is Dictionary:
			var explicit: Variant = (last as Dictionary).get("next_scene")
			if explicit is String:
				next_scene = explicit as String
	if next_scene.is_empty():
		return
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router != null and router.has_method("change_scene"):
		router.call("change_scene", next_scene)
