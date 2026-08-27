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

func _run_tests() -> void:
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

	if _failures == 0:
		print("OPENING_ART_TEST: PASS (" + str(_checks) + " checks)")
		quit(0)
		return
	print("OPENING_ART_TEST: FAIL (" + str(_failures) + "/" + str(_checks) + " checks failed)")
	quit(1)
