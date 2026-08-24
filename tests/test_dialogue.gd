extends SceneTree

var _failures: int = 0
var _finished_id: String = ""

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("DIALOGUE_TEST: START")

	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = load("res://scripts/systems/game_state.gd").new()
		gs.name = "GameState"
		root.add_child(gs)

	_test_valid_dialogue(gs)
	_test_broken_dialogue()
	_test_npc_scene()

	if _failures == 0:
		print("DIALOGUE_TEST: PASS")
		quit(0)
	else:
		print("DIALOGUE_TEST: FAIL (%d assertion(s) failed)" % _failures)
		quit(1)

func _test_valid_dialogue(gs: Node) -> void:
	var json_file := FileAccess.open("res://data/dialogue/dialogue_act1_abenthy_lesson.json", FileAccess.READ)
	_assert_true(json_file != null, "dialogue JSON file opens")
	if json_file == null:
		return

	var json_text := json_file.get_as_text()
	json_file.close()
	var parsed = JSON.parse_string(json_text)
	_assert_true(parsed != null and parsed is Dictionary, "dialogue JSON parses to dictionary")
	if parsed == null or not parsed is Dictionary:
		return

	var data: Dictionary = parsed
	var errors := DialogueRunner.validate(data)
	_assert_eq(errors.size(), 0, "validate returns zero errors for real dialogue")
	if errors.size() > 0:
		for err in errors:
			push_error("validation error: " + err)
		return

	var runner := DialogueRunner.new()
	runner.name = "DialogueRunner"
	runner.dialogue_finished.connect(_on_dialogue_finished)
	root.add_child(runner)

	runner.start(data)
	_assert_eq(runner.get_current_id(), "node_greeting", "runner starts at root node")

	runner._on_choice(0)
	_assert_eq(gs.relationships.get("char_abenthy", 0.0), 1.0, "relationship effect applied")
	_assert_eq(runner.get_current_id(), "node_question", "choice advances to next node")

	runner._on_choice(0)
	_assert_true(gs.has_flag("flag_act1_abenthy_lesson_seen"), "set_flag effect applied")
	_assert_eq(runner.get_current_id(), "node_end", "advances to end node")

	# End node should hide UI and emit finished (already emitted by _on_choice).
	_assert_eq(_finished_id, "dialogue_act1_abenthy_lesson", "dialogue_finished emitted with dialogue_id")

	var panel: Control = runner.get_child(0)
	if panel != null:
		_assert_false(panel.visible, "UI hidden after end node")
	else:
		push_error("ASSERT FAIL: runner has no child panel")
		_failures += 1

	runner.queue_free()

func _test_broken_dialogue() -> void:
	var broken := {
		"dialogue_id": "broken",
		"root": "a",
		"nodes": {
			"a": {
				"speaker": "x",
				"text": "y",
				"next": "missing"
			}
		}
	}
	var errors := DialogueRunner.validate(broken)
	_assert_true(errors.size() >= 1, "broken dialogue reports at least one error")

	var found_missing := false
	for err in errors:
		if err.find("missing") >= 0:
			found_missing = true
			break
	_assert_true(found_missing, "broken dialogue error mentions missing reference")

func _test_npc_scene() -> void:
	var scene := load("res://scenes/npcs/npc.tscn") as PackedScene
	_assert_true(scene != null, "npc scene loads")
	if scene == null:
		return

	var instance := scene.instantiate()
	_assert_true(instance != null, "npc scene instantiates")
	if instance != null:
		instance.queue_free()

func _on_dialogue_finished(dialogue_id: String) -> void:
	_finished_id = dialogue_id

func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		push_error("ASSERT FAIL: %s (expected %s, got %s)" % [message, str(expected), str(actual)])
		_failures += 1

func _assert_true(actual: bool, message: String) -> void:
	if not actual:
		push_error("ASSERT FAIL: %s (expected true)" % message)
		_failures += 1

func _assert_false(actual: bool, message: String) -> void:
	if actual:
		push_error("ASSERT FAIL: %s (expected false)" % message)
		_failures += 1
