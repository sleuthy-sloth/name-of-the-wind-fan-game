extends SceneTree

## Captures the opening presentation from real Godot scenes at the project's
## fixed 1280×720 viewport. This tool deliberately does not load saved games.

const CAPTURES := [
	{"scene": "res://scenes/ui/title_menu.tscn", "file": "res://docs/screenshots/title-chronicle.png"},
	{"scene": "res://scenes/world/waystone_inn.tscn", "file": "res://docs/screenshots/waystone-prologue.png"},
	{"scene": "res://scenes/world/caravan_route.tscn", "file": "res://docs/screenshots/caravan-dawn.png"},
]

const SCREENSHOT_SIZE := Vector2i(1280, 720)
const TITLE_SCENE := "res://scenes/ui/title_menu.tscn"
const CARAVAN_SCENE := "res://scenes/world/caravan_route.tscn"
const TITLE_NO_SAVE_META := &"capture_force_no_save_continue"
const CARAVAN_CAPTURE_FOCUS := Vector2(350, 200)
const CARAVAN_CAPTURE_ZOOM := Vector2(1.5, 1.5)

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings := root.get_node_or_null("Settings")
	var prior_reduce_motion := false
	if settings != null:
		prior_reduce_motion = bool(settings.get("reduce_motion"))
		settings.call("set_reduce_motion", true)

	for capture in CAPTURES:
		await _capture(capture)

	root.remove_meta(TITLE_NO_SAVE_META)
	if settings != null:
		settings.call("set_reduce_motion", prior_reduce_motion)

	print("OPENING_SCREENSHOT_CAPTURE: %s" % ("PASS" if _failures == 0 else "FAIL (%d failure(s))" % _failures))
	quit(0 if _failures == 0 else 1)


func _capture(capture: Dictionary) -> void:
	var scene_path := String(capture["scene"])
	var file_path := String(capture["file"])
	_configure_scene(scene_path)
	var scene_error := change_scene_to_file(scene_path)
	if scene_error != OK:
		_fail("could not load %s (error %d)" % [scene_path, scene_error])
		return

	# Two idle frames let scene _ready handlers and tweens settle. A third
	# process frame is intentionally used instead of waiting on
	# RenderingServer.frame_post_draw, which is not emitted by every headless
	# rendering backend.
	await process_frame
	await process_frame
	await process_frame
	if not _frame_caravan(scene_path):
		return
	await process_frame

	var viewport := get_root().get_viewport()
	var texture := viewport.get_texture()
	if texture == null:
		_fail("viewport texture is unavailable for %s; run with a graphical renderer" % scene_path)
		return
	var image := texture.get_image()
	if image == null:
		_fail("could not read viewport image for %s" % scene_path)
		return
	if image.get_size() != SCREENSHOT_SIZE:
		_fail("%s was %s, expected %s" % [file_path, image.get_size(), SCREENSHOT_SIZE])
		return

	var write_error := image.save_png(ProjectSettings.globalize_path(file_path))
	if write_error != OK:
		_fail("could not write %s (error %d)" % [file_path, write_error])


func _configure_scene(scene_path: String) -> void:
	if scene_path == TITLE_SCENE:
		root.set_meta(TITLE_NO_SAVE_META, true)
	else:
		root.remove_meta(TITLE_NO_SAVE_META)


func _frame_caravan(scene_path: String) -> bool:
	if scene_path != CARAVAN_SCENE:
		return true
	var caravan := current_scene
	if caravan == null:
		_fail("caravan scene is unavailable after loading")
		return false
	var camera := caravan.get_node_or_null("Player/Camera2D") as Camera2D
	if camera == null:
		_fail("could not find caravan player camera")
		return false
	camera.position_smoothing_enabled = false
	camera.global_position = CARAVAN_CAPTURE_FOCUS
	camera.zoom = CARAVAN_CAPTURE_ZOOM
	camera.make_current()
	return true


func _fail(message: String) -> void:
	_failures += 1
	printerr("OPENING_SCREENSHOT_CAPTURE: " + message)
