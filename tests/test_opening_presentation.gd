extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _run() -> void:
	_check(ResourceLoader.exists("res://scripts/ui/chronicle_canvas.gd"), "ChronicleCanvas exists")
	_test_interaction_prompt()
	await _test_title_canvas()
	await _test_waystone_prologue()
	await _test_caravan_presentation()
	_check(FileAccess.file_exists("res://tools/capture_opening_screenshots.gd"), "capture tool exists")
	_test_capture_contract()
	print("OPENING_PRESENTATION_TEST: %s" % ("PASS" if _failures == 0 else "FAIL (%d failure(s))" % _failures))
	quit(0 if _failures == 0 else 1)


func _test_interaction_prompt() -> void:
	_check(InteractionPrompt.binding_label(&"interact") == "E", "interact binding resolves to E")
	var label := Label.new()
	InteractionPrompt.configure(label, &"interact", "Speak with Abenthy", Color.WHITE)
	_check(label.text == "[E] Speak with Abenthy", "prompt combines binding and context")


func _test_title_canvas() -> void:
	var packed := load("res://scenes/ui/title_menu.tscn") as PackedScene
	_check(packed != null, "title scene loads")
	if packed == null:
		return
	root.set_meta(&"capture_force_no_save_continue", true)
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	var canvas := scene.get_node_or_null("ChronicleCanvas")
	_check(canvas != null, "title contains ChronicleCanvas")
	if canvas != null:
		var signature: Dictionary = canvas.render_signature()
		_check(signature.get("illustration") == "title_page", "title illustration is a chronicle page")
		_check(int(signature.get("layer_count", 0)) >= 6, "title has six visual layers")
	var continue_button := scene.get_node_or_null("Buttons/ContinueButton") as Button
	_check(continue_button != null and continue_button.disabled, "capture title disables Continue without a save")
	_check(continue_button != null and continue_button.text == "Continue (no save)", "capture title labels Continue as no-save")
	scene.queue_free()
	root.remove_meta(&"capture_force_no_save_continue")


func _test_waystone_prologue() -> void:
	var packed := load("res://scenes/world/waystone_inn.tscn") as PackedScene
	_check(packed != null, "Waystone prologue loads")
	if packed != null:
		var scene := packed.instantiate()
		root.add_child(scene)
		await process_frame
		var canvas := scene.get_node_or_null("ChronicleCanvas")
		_check(canvas != null, "Waystone has ChronicleCanvas")
		if canvas != null:
			_check(canvas.render_signature().get("illustration") == "waystone_fire", "Waystone draws fireplace page")
		scene.queue_free()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/waystone_opening.json"))
	var beats: Array = data.get("beats", [])
	_check((beats.back() as Dictionary).get("next_scene") == "res://scenes/world/caravan_route.tscn", "Waystone routes to caravan")


func _test_caravan_presentation() -> void:
	var packed := load("res://scenes/world/caravan_route.tscn") as PackedScene
	_check(packed != null, "caravan scene loads")
	if packed == null:
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var presentation := scene.get_node_or_null("CaravanPresentation")
	_check(presentation != null, "caravan instances presentation")
	for layer_name in ["Canopy", "Wagons", "Tents", "Campfire", "Shadows", "Atmosphere"]:
		_check(presentation != null and presentation.get_node_or_null(layer_name) != null, "caravan has " + layer_name)
	scene.queue_free()


func _test_capture_contract() -> void:
	var source := FileAccess.get_file_as_string("res://tools/capture_opening_screenshots.gd")
	var expected_captures := [
		{"scene": "res://scenes/ui/title_menu.tscn", "file": "res://docs/screenshots/title-chronicle.png"},
		{"scene": "res://scenes/world/waystone_inn.tscn", "file": "res://docs/screenshots/waystone-prologue.png"},
		{"scene": "res://scenes/world/caravan_route.tscn", "file": "res://docs/screenshots/caravan-dawn.png"},
	]
	for capture in expected_captures:
		var mapping := "{\"scene\": \"%s\", \"file\": \"%s\"}" % [capture["scene"], capture["file"]]
		_check(source.contains(mapping), "capture maps " + capture["file"])
	_check(source.count("{\"scene\":") == expected_captures.size(), "capture declares exactly three scenes")
	_check(source.contains("const SCREENSHOT_SIZE := Vector2i(1280, 720)"), "capture declares 1280x720 guard")
	_check(source.contains("image.get_size() != SCREENSHOT_SIZE"), "capture rejects wrong dimensions")
	_check(source.contains("prior_reduce_motion"), "capture records prior reduce-motion value")
	_check(source.contains("set_reduce_motion\", true"), "capture enables reduce motion")
	_check(source.contains("set_reduce_motion\", prior_reduce_motion"), "capture restores reduce motion")
	_check(not source.contains("SaveManager"), "capture does not access SaveManager")
	_check(not source.contains("user://"), "capture does not access user save storage")
	_check(source.contains("capture_force_no_save_continue"), "capture forces title's no-save state")
	_check(source.contains("root.set_meta(TITLE_NO_SAVE_META, true)"), "capture isolates title from player save state")
	_check(source.contains("root.remove_meta(TITLE_NO_SAVE_META)"), "capture restores title capture state")
	_check(source.contains("_frame_caravan"), "capture reframes the caravan scene")
	_check(source.contains("if caravan == null"), "capture fails when caravan scene is unavailable")
	var title_source := FileAccess.get_file_as_string("res://scripts/ui/title_menu.gd")
	var continue_state := title_source.find("func _apply_continue_state")
	var override_check := title_source.find("get_meta(CAPTURE_FORCE_NO_SAVE_CONTINUE_META", continue_state)
	var save_access := title_source.find("get_node_or_null(\"/root/SaveManager\")", continue_state)
	_check(override_check != -1 and override_check < save_access, "title override runs before SaveManager access")
	for capture in expected_captures:
		var screenshot_path := String(capture["file"])
		_check(FileAccess.file_exists(screenshot_path), "screenshot exists: " + screenshot_path)
		if FileAccess.file_exists(screenshot_path):
			_check(_png_dimensions(screenshot_path) == Vector2i(1280, 720), "screenshot is 1280x720: " + screenshot_path)


func _png_dimensions(path: String) -> Vector2i:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Vector2i.ZERO
	var bytes := file.get_buffer(24)
	if bytes.size() != 24 or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		return Vector2i.ZERO
	var width := (int(bytes[16]) << 24) | (int(bytes[17]) << 16) | (int(bytes[18]) << 8) | int(bytes[19])
	var height := (int(bytes[20]) << 24) | (int(bytes[21]) << 16) | (int(bytes[22]) << 8) | int(bytes[23])
	return Vector2i(width, height)
