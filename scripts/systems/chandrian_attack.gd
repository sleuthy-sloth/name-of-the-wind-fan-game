class_name ChandrianAttack
extends Node

const DIALOGUE_PATH := "res://data/dialogue/dialogue_act1_chandrian_attack.json"
const DEFAULT_NEXT_SCENE := "res://scenes/world/escape_aftermath.tscn"

@export var mode: String = "attack"

var _beats: Array = []
var _current_beat_index: int = -1
var _complete: bool = false
var _started: bool = false
var _overlay: ColorRect = null
var _label: RichTextLabel = null
var _tween: Tween = null

func _ready() -> void:
	_overlay = _find_overlay()
	_label = _find_label()
	_setup_ambience()
	call_deferred("start_sequence")

## Moody wind bed per phase; a thunder crack opens the attack itself.
func _setup_ambience() -> void:
	var bed_event := "AMB_WIND_LIGHT_LAYER"
	if mode == "attack":
		bed_event = "SFX_WIND_STRONG"
	var stream := AudioLibrary.stream_for(bed_event)
	if stream is AudioStream:
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		var player := AudioStreamPlayer.new()
		player.name = "AmbiencePlayer"
		player.stream = stream
		player.volume_db = -10.0
		player.autoplay = true
		add_child(player)
	if mode == "attack":
		var timer := get_tree().create_timer(0.6)
		timer.timeout.connect(func() -> void: AudioLibrary.play("SFX_THUNDER", -4.0))

func _find_overlay() -> ColorRect:
	var layer: CanvasLayer = get_node_or_null("OverlayLayer")
	if layer != null:
		return layer.get_node_or_null("Overlay") as ColorRect
	return get_node_or_null("Overlay") as ColorRect

func _find_label() -> RichTextLabel:
	var layer: CanvasLayer = get_node_or_null("TextLayer")
	if layer != null:
		return layer.get_node_or_null("NarrationLabel") as RichTextLabel
	return get_node_or_null("NarrationLabel") as RichTextLabel

func start_sequence() -> void:
	if _started:
		return
	_started = true
	_complete = false
	_current_beat_index = -1

	var data: Variant = _load_json(DIALOGUE_PATH)
	if data == null or not data is Dictionary:
		push_error("ChandrianAttack: failed to load beat data")
		_complete = true
		return

	var dict: Dictionary = data as Dictionary
	var key := "beats"
	if mode == "aftermath":
		key = "aftermath_beats"

	var raw_beats: Variant = dict.get(key)
	if raw_beats == null or not raw_beats is Array:
		push_error("ChandrianAttack: no '%s' array found" % key)
		_complete = true
		return

	_beats = raw_beats as Array
	_advance_beat()

func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ChandrianAttack: could not open %s" % path)
		return null
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed

func _advance_beat() -> void:
	_current_beat_index += 1
	if _current_beat_index >= _beats.size():
		_complete = true
		_trigger_final_transition()
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

	var effect: String = beat.get("effect", "calm")
	_apply_effect(effect)

	var flag: String = beat.get("set_flag", "")
	if not flag.is_empty():
		var gs: Node = _game_state()
		if gs != null:
			gs.set_flag(flag)

	if beat.get("autosave", false) == true:
		var sm: Node = _save_manager()
		if sm != null:
			sm.save_game(0)

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
		"fade_to_red":
			_tween.tween_property(_overlay, "color", Color(0.45, 0.0, 0.0, 0.65), 1.2)
		"screen_shake":
			_tween.tween_property(_overlay, "color", Color(0.2, 0.0, 0.0, 0.35), 0.1)
		"darkness":
			_tween.tween_property(_overlay, "color", Color(0.0, 0.0, 0.0, 0.95), 1.5)
		_:
			_tween.tween_property(_overlay, "color", Color(0.0, 0.0, 0.0, 0.0), 0.5)

func _trigger_final_transition() -> void:
	var beat: Variant = _beats[_beats.size() - 1] if _beats.size() > 0 else null
	var next_scene := DEFAULT_NEXT_SCENE
	if beat != null and beat is Dictionary:
		var explicit: Variant = (beat as Dictionary).get("next_scene")
		if explicit != null and explicit is String and not (explicit as String).is_empty():
			next_scene = explicit as String

	var router: Node = _scene_router()
	if router != null:
		router.change_scene(next_scene)

func is_sequence_complete() -> bool:
	return _complete

func _game_state() -> Variant:
	return get_node_or_null("/root/GameState")

func _save_manager() -> Variant:
	return get_node_or_null("/root/SaveManager")

func _scene_router() -> Variant:
	return get_node_or_null("/root/SceneRouter")
