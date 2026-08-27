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
	_check(ResourceLoader.exists("res://scripts/world/caravan_presentation.gd"), "CaravanPresentation exists")
	_check(FileAccess.file_exists("res://tools/capture_opening_screenshots.gd"), "capture tool exists")
	print("OPENING_PRESENTATION_TEST: %s" % ("PASS" if _failures == 0 else "FAIL (%d failure(s))" % _failures))
	quit(0 if _failures == 0 else 1)
