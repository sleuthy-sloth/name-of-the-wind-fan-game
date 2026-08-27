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
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	var canvas := scene.get_node_or_null("ChronicleCanvas")
	_check(canvas != null, "title contains ChronicleCanvas")
	if canvas != null:
		var signature: Dictionary = canvas.render_signature()
		_check(signature.get("illustration") == "title_page", "title illustration is a chronicle page")
		_check(int(signature.get("layer_count", 0)) >= 6, "title has six visual layers")
	scene.queue_free()


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
