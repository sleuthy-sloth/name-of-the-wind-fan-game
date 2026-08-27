extends SceneTree

## Captures the opening presentation from real Godot scenes at the project's
## fixed 1280×720 viewport. This tool deliberately does not load saved games.

const CAPTURES := [
	{"scene": "res://scenes/ui/title_menu.tscn", "file": "res://docs/screenshots/title-chronicle.png"},
	{"scene": "res://scenes/world/waystone_inn.tscn", "file": "res://docs/screenshots/waystone-prologue.png"},
	{"scene": "res://scenes/world/caravan_route.tscn", "file": "res://docs/screenshots/caravan-dawn.png"},
]

const SCREENSHOT_SIZE := Vector2i(1280, 720)

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

	if settings != null:
		settings.call("set_reduce_motion", prior_reduce_motion)

	print("OPENING_SCREENSHOT_CAPTURE: %s" % ("PASS" if _failures == 0 else "FAIL (%d failure(s))" % _failures))
	quit(0 if _failures == 0 else 1)


func _capture(capture: Dictionary) -> void:
	var scene_path := String(capture["scene"])
	var file_path := String(capture["file"])
	var scene_error := change_scene_to_file(scene_path)
	if scene_error != OK:
		_fail("could not load %s (error %d)" % [scene_path, scene_error])
		return

	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	if image == null:
		_fail("could not read viewport image for %s" % scene_path)
		return
	if image.get_size() != SCREENSHOT_SIZE:
		_fail("%s was %s, expected %s" % [file_path, image.get_size(), SCREENSHOT_SIZE])
		return

	var write_error := image.save_png(ProjectSettings.globalize_path(file_path))
	if write_error != OK:
		_fail("could not write %s (error %d)" % [file_path, write_error])


func _fail(message: String) -> void:
	_failures += 1
	printerr("OPENING_SCREENSHOT_CAPTURE: " + message)
