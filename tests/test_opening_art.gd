extends SceneTree

var _checks := 0
var _failures := 0

func _initialize() -> void:
	_run_tests.call_deferred()

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("CHECK: " + description + " PASS")
		return
	_failures += 1
	print("CHECK: " + description + " FAIL")

func _sha256_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(file.get_buffer(file.get_length()))
	return context.finish().hex_encode()

func _gameplay_layers(project: Dictionary) -> Array:
	var snapshots: Array = []
	for level_variant in project.get("levels", []) as Array:
		var level := level_variant as Dictionary
		var gameplay_layers: Array = []
		for layer_variant in level.get("layerInstances", []) as Array:
			var layer := layer_variant as Dictionary
			if layer.get("__type") in ["IntGrid", "Entities"]:
				gameplay_layers.append(layer)
		snapshots.append({
			"identifier": level.get("identifier", ""),
			"layerInstances": gameplay_layers,
		})
	return snapshots

func _layer_by_name(project: Dictionary, layer_name: String) -> Dictionary:
	var levels := project.get("levels", []) as Array
	if levels.is_empty():
		return {}
	for layer_variant in (levels[0] as Dictionary).get("layerInstances", []) as Array:
		var layer := layer_variant as Dictionary
		if layer.get("identifier") == layer_name:
			return layer
	return {}

func _contains_collision_object(node: Node) -> bool:
	if node is CollisionObject2D:
		return true
	for child in node.get_children():
		if _contains_collision_object(child):
			return true
	return false

func _test_caravan_presentation() -> void:
	var caravan_source := FileAccess.get_file_as_string("res://scripts/world/caravan_presentation.gd")
	_check(not caravan_source.contains("draw_colored_polygon"), "caravan no longer draws primitive tents or fire")
	_check(not caravan_source.contains("draw_circle"), "caravan no longer draws primitive trees or wheels")
	_check(caravan_source.contains("res://art/generated/opening_art/caravan_wagon_a.png"), "caravan loads generated wagon art")

	for texture_path in [
		"res://art/generated/opening_art/caravan_wagon_a.png",
		"res://art/generated/opening_art/caravan_wagon_b.png",
		"res://art/generated/opening_art/campfire.png",
		"res://art/generated/opening_art/tent_shadow.png",
	]:
		_check(FileAccess.file_exists(texture_path), "generated caravan texture exists: " + texture_path)
		if FileAccess.file_exists(texture_path):
			_check(load(texture_path) is Texture2D, "generated caravan texture loads: " + texture_path)

	var packed := load("res://scenes/world/caravan_presentation.tscn") as PackedScene
	_check(packed != null, "caravan presentation scene loads")
	if packed == null:
		return
	var presentation := packed.instantiate()
	root.add_child(presentation)
	_check(not _contains_collision_object(presentation), "caravan presentation remains visual-only")
	_check(presentation.has_method("set_reduced_motion"), "caravan exposes reduced-motion control")
	if presentation.has_method("set_reduced_motion"):
		presentation.call("set_reduced_motion", true)
		var elapsed_before := float(presentation.get("_elapsed"))
		presentation.call("_process", 1.0)
		_check(is_equal_approx(float(presentation.get("_elapsed")), elapsed_before), "reduced motion freezes caravan atmosphere")
	presentation.queue_free()

func _run_tests() -> void:
	_test_caravan_presentation()
	for record_path in [
		"res://art/tilesets/openrtp/PROVENANCE.json",
		"res://art/tilesets/gloomy_fantasy/PROVENANCE.json",
		"res://art/props/frontier_wagons/PROVENANCE.json",
		"res://art/tilesets/kenney_rpg_urban/PROVENANCE.json",
	]:
		_check(FileAccess.file_exists(record_path), "provenance exists: " + record_path)
		if not FileAccess.file_exists(record_path):
			continue
		var record := JSON.parse_string(FileAccess.get_file_as_string(record_path)) as Dictionary
		_check(record.get("license") == "CC0-1.0", "source is CC0: " + record_path)
		_check(record.has("sha256") and record.has("source_url"), "source is auditable: " + record_path)
		var hashes := record.get("sha256", {}) as Dictionary
		for source_file_variant in record.get("files", []) as Array:
			var source_file := str(source_file_variant)
			var source_path: String = record_path.get_base_dir().path_join(source_file)
			_check(hashes.has(source_file), "source hash recorded: " + source_path)
			_check(FileAccess.file_exists(source_path), "source file exists: " + source_path)
			if hashes.has(source_file) and FileAccess.file_exists(source_path):
				_check(
					_sha256_file(source_path) == hashes[source_file],
					"source hash matches: " + source_path,
				)

	var baseline_path := "res://tests/fixtures/opening_art_baseline.json"
	_check(FileAccess.file_exists(baseline_path), "opening map gameplay baseline exists")
	var baseline := JSON.parse_string(FileAccess.get_file_as_string(baseline_path)) as Dictionary
	var transparent_exterior_path := "res://art/tilesets/openrtp/derived/exterior_transparent.png"
	var derivative_record_path := "res://art/tilesets/openrtp/derived/PROVENANCE.json"
	_check(FileAccess.file_exists(transparent_exterior_path), "transparent OpenRTP exterior derivative exists")
	_check(FileAccess.file_exists(derivative_record_path), "transparent OpenRTP derivative provenance exists")
	if FileAccess.file_exists(derivative_record_path):
		var derivative_record := JSON.parse_string(FileAccess.get_file_as_string(derivative_record_path)) as Dictionary
		_check(derivative_record.get("derived_from") == "../exterior.png", "transparent derivative identifies its upstream source")
		_check(
			derivative_record.get("source_sha256") == _sha256_file("res://art/tilesets/openrtp/exterior.png"),
			"transparent derivative records the upstream source hash",
		)
		_check(
			derivative_record.get("derived_sha256") == _sha256_file(transparent_exterior_path),
			"transparent derivative hash matches",
		)
	if FileAccess.file_exists(transparent_exterior_path):
		var exterior_texture := load(transparent_exterior_path) as Texture2D
		var exterior_image := exterior_texture.get_image()
		var visible_chroma_pixels := 0
		var transparent_pixels := 0
		for pixel_y in range(exterior_image.get_height()):
			for pixel_x in range(exterior_image.get_width()):
				var pixel := exterior_image.get_pixel(pixel_x, pixel_y)
				if pixel.a < 0.01:
					transparent_pixels += 1
				elif pixel.r8 == 255 and pixel.g8 == 103 and pixel.b8 == 139:
					visible_chroma_pixels += 1
		_check(visible_chroma_pixels == 0, "derived Props atlas has no visible magenta chroma key")
		_check(transparent_pixels > 0, "derived Props atlas contains transparent pixels")
	for map_record in [
		{"id": "caravan_route", "path": "res://maps/caravan_route.ldtk"},
		{"id": "forest_campsite", "path": "res://maps/forest_campsite.ldtk"},
	]:
		var map_id := map_record["id"] as String
		var map_path := map_record["path"] as String
		var source := FileAccess.get_file_as_string(map_path)
		var project := JSON.parse_string(source) as Dictionary
		_check(not source.contains("zeldalike_overworld.png"), "legacy atlas removed: " + map_path)
		_check(source.contains("openrtp/world.png"), "OpenRTP world atlas mapped: " + map_path)
		_check(source.contains("openrtp/derived/exterior_transparent.png"), "transparent OpenRTP exterior atlas mapped: " + map_path)
		_check(
			_layer_by_name(project, "Ground").get("__tilesetRelPath") == "../art/tilesets/openrtp/world.png",
			"Ground owns the OpenRTP world atlas: " + map_path,
		)
		_check(
			_layer_by_name(project, "Props").get("__tilesetRelPath") == "../art/tilesets/openrtp/derived/exterior_transparent.png",
			"Props owns the transparent OpenRTP exterior atlas: " + map_path,
		)
		_check(
			_gameplay_layers(project) == baseline.get(map_id, []),
			"gameplay layers preserved: " + map_path,
		)

	if _failures == 0:
		print("OPENING_ART_TEST: PASS (" + str(_checks) + " checks)")
		quit(0)
		return
	print("OPENING_ART_TEST: FAIL (" + str(_failures) + "/" + str(_checks) + " checks failed)")
	quit(1)
