## SympathyLighting
# Visual response layer for light/heat Sympathy workings (GDD §17.3).
# Uses palette-swap modulate animation and stacked semi-transparent masks
# instead of real-time lighting; audio feedback is generated in code.
class_name SympathyLighting
extends Node2D

@export var tween_duration: float = 0.3

var _source_baseline_modulate: Color = Color.WHITE
var _target_baseline_modulate: Color = Color.WHITE
var _ambient_baseline: Color = Color(0.9, 0.85, 0.8, 0.25)

var _last_result: Dictionary = {}
var _last_feedback_frequency: float = 0.0
var _lute_samples: Dictionary = {}

@onready var _source_node: CanvasItem = _ensure_source()
@onready var _target_node: CanvasItem = _ensure_target()
@onready var _ambient_overlay: ColorRect = _ensure_ambient()
@onready var _mask_container: Node2D = _ensure_masks()
@onready var _feedback_player: AudioStreamPlayer = _ensure_feedback_player()


func apply_sympathy_result(result: Dictionary) -> void:
	_last_result = result.duplicate()
	_apply_result(result, false)


func apply_instant(result: Dictionary = {}) -> void:
	var applied: Dictionary = result
	if applied.is_empty() and not _last_result.is_empty():
		applied = _last_result
	_apply_result(applied, true)


func play_feedback(domain: String) -> void:
	var freq: float = 880.0 if domain == "light" else 220.0
	var duration: float = 0.25
	var volume_db: float = -6.0 if domain == "light" else -3.0
	_last_feedback_frequency = freq
	if _try_lute_sample(domain, volume_db):
		return
	_feedback_player.stream = _generate_tone(freq, duration)
	_feedback_player.volume_db = volume_db
	_feedback_player.play()


func _try_lute_sample(domain: String, volume_db: float) -> bool:
	if _feedback_player == null:
		return false
	if _lute_samples.is_empty():
		_load_lute_samples()
	var note_name: String = "A4" if domain == "light" else "D3"
	if not _lute_samples.has(note_name):
		return false
	_feedback_player.stream = _lute_samples[note_name]
	_feedback_player.volume_db = volume_db
	_feedback_player.play()
	return true


func _load_lute_samples() -> void:
	var notes: Array[String] = ["D3", "G3", "A3", "B3", "D4", "E4", "G4", "A4"]
	for note_name in notes:
		var path := "res://audio/sfx/lute_%s.ogg" % note_name
		var stream := load(path)
		if stream is AudioStream:
			_lute_samples[note_name] = stream


func get_source_modulate() -> Color:
	if _source_node == null:
		return Color.BLACK
	return _source_node.modulate


func get_target_modulate() -> Color:
	if _target_node == null:
		return Color.BLACK
	return _target_node.modulate


func get_ambient_color() -> Color:
	if _ambient_overlay == null:
		return Color.BLACK
	return _ambient_overlay.modulate


func get_mask_layer_count() -> int:
	if _mask_container == null:
		return 0
	return _mask_container.get_child_count()


func get_last_feedback_frequency() -> float:
	return _last_feedback_frequency


func _apply_result(result: Dictionary, instant: bool) -> void:
	var payload: Dictionary = result.get("effect_applied", {})
	if payload.is_empty():
		payload = result.duplicate()

	var domain: String = payload.get("domain", "")
	var source_dim: float = clampf(payload.get("source_dim", 0.0), 0.0, 1.0)
	var target_brighten: float = clampf(payload.get("target_brighten", 0.0), 0.0, 5.0)

	var source_target: Color = _source_baseline_modulate * (1.0 - source_dim)
	var target_target: Color = _target_color(domain, target_brighten)
	var ambient_target: Color = _ambient_target_color(domain)
	var mask_color: Color = _mask_target_color(domain)

	if instant:
		_source_node.modulate = source_target
		_target_node.modulate = target_target
		_ambient_overlay.modulate = ambient_target
		for mask: CanvasItem in _mask_container.get_children():
			mask.modulate = mask_color
	else:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_source_node, "modulate", source_target, tween_duration)
		tween.tween_property(_target_node, "modulate", target_target, tween_duration)
		tween.tween_property(_ambient_overlay, "modulate", ambient_target, tween_duration)
		var mask_index: int = 0
		for mask: CanvasItem in _mask_container.get_children():
			var delay: float = float(mask_index) * 0.05
			tween.tween_property(mask, "modulate", mask_color, tween_duration).set_delay(delay)
			mask_index += 1


func _target_color(domain: String, brighten: float) -> Color:
	var factor: float = 1.0 + brighten
	if domain == "heat":
		return Color(factor, factor * 0.85, factor * 0.7, 1.0)
	return Color(factor, factor, factor, 1.0)


func _ambient_target_color(domain: String) -> Color:
	var base: Color = _ambient_baseline
	if domain == "light":
		return Color(clampf(base.r * 0.75, 0.0, 1.0), clampf(base.g * 0.9, 0.0, 1.0), clampf(base.b * 1.15, 0.0, 1.0), clampf(base.a * 1.5, 0.0, 1.0))
	if domain == "heat":
		return Color(clampf(base.r * 1.15, 0.0, 1.0), clampf(base.g * 0.9, 0.0, 1.0), clampf(base.b * 0.75, 0.0, 1.0), clampf(base.a * 1.5, 0.0, 1.0))
	return base


func _mask_target_color(domain: String) -> Color:
	if domain == "heat":
		return Color(1.0, 0.6, 0.3, 0.25)
	return Color(0.7, 0.8, 1.0, 0.25)


func _ensure_source() -> CanvasItem:
	var node: Node = get_node_or_null("CampfireSource")
	if node == null:
		var rect := ColorRect.new()
		rect.name = "CampfireSource"
		rect.custom_minimum_size = Vector2(64, 64)
		rect.size = Vector2(64, 64)
		rect.position = Vector2(120, 300)
		rect.color = Color(0.9, 0.45, 0.15, 1.0)
		rect.modulate = _source_baseline_modulate
		add_child(rect)
		return rect
	if node is CanvasItem:
		return node as CanvasItem
	return node


func _ensure_target() -> CanvasItem:
	var node: Node = get_node_or_null("LampTarget")
	if node == null:
		var rect := ColorRect.new()
		rect.name = "LampTarget"
		rect.custom_minimum_size = Vector2(48, 48)
		rect.size = Vector2(48, 48)
		rect.position = Vector2(520, 300)
		rect.color = Color(0.95, 0.95, 0.8, 1.0)
		rect.modulate = _target_baseline_modulate
		add_child(rect)
		return rect
	if node is CanvasItem:
		return node as CanvasItem
	return node


func _ensure_ambient() -> ColorRect:
	var node: Node = get_node_or_null("AmbientOverlay")
	if node == null:
		var rect := ColorRect.new()
		rect.name = "AmbientOverlay"
		rect.size = Vector2(640, 360)
		rect.position = Vector2(0, 0)
		rect.color = Color.WHITE
		rect.modulate = _ambient_baseline
		add_child(rect)
		return rect
	if node is ColorRect:
		return node as ColorRect
	return node as ColorRect


func _ensure_masks() -> Node2D:
	var container: Node = get_node_or_null("MaskLayers")
	if container == null:
		container = Node2D.new()
		container.name = "MaskLayers"
		add_child(container)

	var needed: int = 3 - container.get_child_count()
	for i: int in range(needed):
		var mask := ColorRect.new()
		mask.name = "Mask%d" % (i + 1)
		mask.size = Vector2(128, 128)
		mask.position = Vector2(220 + i * 80, 200)
		mask.color = Color.WHITE
		mask.modulate = Color(1.0, 1.0, 1.0, 0.0)
		container.add_child(mask)
	return container as Node2D


func _ensure_feedback_player() -> AudioStreamPlayer:
	var player: Node = get_node_or_null("FeedbackPlayer")
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "FeedbackPlayer"
		add_child(player)
	return player as AudioStreamPlayer


func _generate_tone(freq_hz: float, duration: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false

	var sample_rate: int = 22050
	var sample_count: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	var amplitude: float = 0.7 * 32767.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(sample_rate)
		var sample: int = int(amplitude * sin(2.0 * PI * freq_hz * t))
		data.encode_s16(i * 2, sample)

	stream.data = data
	return stream
