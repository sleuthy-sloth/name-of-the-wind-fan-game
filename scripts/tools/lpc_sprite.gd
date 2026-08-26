class_name LpcSprite
extends Sprite2D

## LpcSprite
# Animated Sprite2D for LPC factory sheets. Reads the frame-data JSON
# emitted by the factory (meta.animations[anim] = {row, y, frames,
# directions, frameSize}) and advances region_rect frames on a timer.
# Direction rows are ordered up, left, down, right per animation block.
#
# Usage:
#   var sprite := LpcSprite.new()
#   sprite.load_sheet("res://art/sprites/lpc/kvothe_caravan")
#   sprite.play("walk"); sprite.set_direction("left")
#
# Falls back to a static first frame when data is missing so scenes stay
# renderable (and headless-testable) even if art is absent.

const DIRECTION_ORDER := ["up", "left", "down", "right"]

var _anims: Dictionary = {}          # anim -> meta dict
var _current_anim := ""
var _direction := "down"
var _frame := 0
var _accum := 0.0
var _fps := 8.0

@export var sheet_base: String = "":
	set(value):
		sheet_base = value
		if value != "":
			load_sheet(value)

@export var autoplay_anim: String = "idle"

func _ready() -> void:
	if sheet_base != "" and _anims.is_empty():
		load_sheet(sheet_base)
	if _current_anim == "" and _anims.has(autoplay_anim):
		play(autoplay_anim)

## Load `<base>.png` + `<base>.json` from the art tree.
func load_sheet(base_path: String) -> bool:
	_anims.clear()
	var tex_path := base_path + ".png"
	var json_path := base_path + ".json"
	if not ResourceLoader.exists(tex_path) or not FileAccess.file_exists(json_path):
		push_warning("LpcSprite: missing sheet for '%s'" % base_path)
		return false
	texture = load(tex_path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("LpcSprite: bad frame data '%s'" % json_path)
		return false
	var meta: Dictionary = (parsed as Dictionary).get("meta", {})
	var anims: Variant = meta.get("animations", {})
	if typeof(anims) != TYPE_DICTIONARY:
		return false
	for anim: String in (anims as Dictionary):
		var entry: Variant = (anims as Dictionary)[anim]
		if typeof(entry) == TYPE_DICTIONARY:
			_anims[anim] = entry as Dictionary
	return not _anims.is_empty()

func has_animation(anim: String) -> bool:
	return _anims.has(anim)

func play(anim: String, restart := false) -> void:
	if not _anims.has(anim):
		return
	if _current_anim == anim and not restart:
		return
	_current_anim = anim
	_frame = 0
	_accum = 0.0
	_apply_frame()

func set_direction(dir: String) -> void:
	if dir == _direction:
		return
	_direction = dir
	_apply_frame()

func current_animation() -> String:
	return _current_anim

func set_fps(fps: float) -> void:
	_fps = maxf(fps, 0.5)

func _process(delta: float) -> void:
	var meta := _current_meta()
	if meta.is_empty():
		return
	_accum += delta * _fps
	var frames := int(meta.get("frames", 1))
	if _accum >= 1.0:
		_accum = fmod(_accum, 1.0)
		_frame = (_frame + 1) % maxi(frames, 1)
		_apply_frame()

func _current_meta() -> Dictionary:
	return _anims.get(_current_anim, {})

func _apply_frame() -> void:
	var meta := _current_meta()
	if meta.is_empty():
		return
	var frame_size := int(meta.get("frameSize", 64))
	var row_y := int(meta.get("y", 0))
	var frames := int(meta.get("frames", 1))
	var dir_index := DIRECTION_ORDER.find(_direction)
	if dir_index < 0:
		dir_index = DIRECTION_ORDER.find("down")  # 2
	region_enabled = true
	region_rect = Rect2(_frame * frame_size, row_y + dir_index * frame_size,
		frame_size, frame_size)
