extends Node

const FADE_DURATION := 0.2

var is_transitioning := false
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var _sfx_player: AudioStreamPlayer = null

func _ready() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.visible = false
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.offset_left = 0.0
	fade_rect.offset_top = 0.0
	fade_rect.offset_right = 0.0
	fade_rect.offset_bottom = 0.0
	fade_layer.add_child(fade_rect)
	add_child(fade_layer)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "TransitionSfx"
	add_child(_sfx_player)
	var sfx := AudioLibrary.stream_for("SFX_UI_SELECT")
	if sfx is AudioStream:
		_sfx_player.stream = sfx

func change_scene(path: String) -> void:
	if is_transitioning:
		return

	is_transitioning = true
	if _sfx_player != null and _sfx_player.stream != null:
		_sfx_player.play()
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0

	var tween_out := create_tween()
	tween_out.tween_property(fade_rect, "modulate:a", 1.0, FADE_DURATION)
	await tween_out.finished

	get_tree().change_scene_to_file(path)

	var tween_in := create_tween()
	tween_in.tween_property(fade_rect, "modulate:a", 0.0, FADE_DURATION)
	await tween_in.finished

	fade_rect.visible = false
	is_transitioning = false
