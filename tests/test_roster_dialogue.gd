extends SceneTree

var _failures: int = 0

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("ROSTER_DIALOGUE_TEST: START")

	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = load("res://scripts/systems/game_state.gd").new()
		gs.name = "GameState"
		root.add_child(gs)

	_test_roster_loads_three_members(gs)
	_test_all_dialogues_validate()
	_test_tutorial_walkthrough_applies_effects(gs)
	_test_text_by_flag_differs(gs)
	_test_npc_interaction_states()

	if _failures == 0:
		print("ROSTER_DIALOGUE_TEST: PASS")
		quit(0)
	else:
		print("ROSTER_DIALOGUE_TEST: FAIL (%d assertion(s) failed)" % _failures)
		quit(1)

func _test_roster_loads_three_members(gs: Node) -> void:
	var roster := Roster.new(gs)
	var members := roster.list_members()
	_assert_true(members.size() >= 3, "roster loads at least three members")

	var abenthy := roster.get_member("char_abenthy")
	_assert_eq(abenthy.get("display_name"), "Abenthy", "Abenthy is in the roster")

	var sera := roster.get_member("char_troupe_member_01")
	_assert_eq(sera.get("display_name"), "Sera", "Sera is in the roster")

	var pip := roster.get_member("char_troupe_member_02")
	_assert_eq(pip.get("display_name"), "Pip", "Pip is in the roster")

func _test_all_dialogues_validate() -> void:
	var paths := [
		"res://data/dialogue/dialogue_act1_abenthy_lesson.json",
		"res://data/dialogue/dialogue_act1_abenthy_tutorial.json",
		"res://data/dialogue/dialogue_act1_camp_threads.json",
	]

	for path in paths:
		var data := _load_dialogue(path)
		if data.is_empty():
			push_error("ASSERT FAIL: could not load dialogue '%s'" % path)
			_failures += 1
			continue

		var errors := DialogueRunner.validate(data)
		if errors.size() > 0:
			push_error("ASSERT FAIL: dialogue '%s' has validation errors" % path)
			for err in errors:
				push_error("  - " + err)
			_failures += 1
		else:
			_assert_true(true, "dialogue '%s' validates cleanly" % path)

func _test_tutorial_walkthrough_applies_effects(gs: Node) -> void:
	var data := _load_dialogue("res://data/dialogue/dialogue_act1_abenthy_tutorial.json")
	if data.is_empty():
		push_error("ASSERT FAIL: tutorial dialogue could not be loaded")
		_failures += 1
		return

	gs.relationships.clear()
	gs.world_flags.clear()

	var runner := DialogueRunner.new()
	runner.name = "DialogueRunnerTutorial"
	root.add_child(runner)

	runner.start(data)
	_assert_eq(runner.get_current_id(), "node_greeting", "tutorial starts at root node")

	# Choose the curious option (index 0).
	runner._on_choice(0)
	_assert_eq(gs.relationships.get("char_abenthy", 0.0), 2.0, "curious choice applies relationship delta")
	_assert_true(gs.has_flag("flag_abenthy_curious"), "curious choice sets flag")
	_assert_eq(runner.get_current_id(), "node_teaching", "curious choice advances to teaching node")

	runner.queue_free()

func _test_text_by_flag_differs(gs: Node) -> void:
	var data := _load_dialogue("res://data/dialogue/dialogue_act1_abenthy_tutorial.json")
	if data.is_empty():
		push_error("ASSERT FAIL: tutorial dialogue could not be loaded")
		_failures += 1
		return

	var curious_text := _capture_teaching_text(data, gs, 0)
	var cautious_text := _capture_teaching_text(data, gs, 1)

	_assert_false(curious_text.is_empty(), "curious teaching text is not empty")
	_assert_false(cautious_text.is_empty(), "cautious teaching text is not empty")
	_assert_false(curious_text == cautious_text, "text_by_flag produces different text for curious vs cautious")

func _capture_teaching_text(data: Dictionary, gs: Node, choice_index: int) -> String:
	gs.relationships.clear()
	gs.world_flags.clear()

	var runner := DialogueRunner.new()
	runner.name = "DialogueRunnerCapture"
	root.add_child(runner)

	runner.start(data)
	runner._on_choice(choice_index)
	var text := runner.get_current_text()

	runner.queue_free()
	return text

func _test_npc_interaction_states() -> void:
	var paths := [
		"res://scenes/npcs/abenthy.tscn",
		"res://scenes/npcs/troupe_member_01.tscn",
		"res://scenes/npcs/troupe_member_02.tscn",
	]

	var seen_ids: Array[String] = []
	var seen_names: Array[String] = []

	var player := Node2D.new()
	player.name = "TestPlayer"
	player.add_to_group("player")
	root.add_child(player)

	for path in paths:
		var scene := load(path) as PackedScene
		_assert_true(scene != null, "npc scene loads: %s" % path)
		if scene == null:
			continue

		var instance := scene.instantiate() as Npc
		_assert_true(instance != null, "npc scene instantiates: %s" % path)
		if instance == null:
			continue

		instance.name = "TestNpc"
		root.add_child(instance)

		_assert_false(instance.can_interact, "npc '%s' cannot interact before player enters" % instance.npc_id)

		var area: Area2D = instance.get_node_or_null("InteractionArea")
		_assert_true(area != null, "npc '%s' has InteractionArea" % instance.npc_id)
		if area != null:
			area.emit_signal("body_entered", player)
			_assert_true(instance.can_interact, "npc '%s' can interact after player enters" % instance.npc_id)
			area.emit_signal("body_exited", player)
			_assert_false(instance.can_interact, "npc '%s' cannot interact after player exits" % instance.npc_id)

		_assert_false(instance.npc_id in seen_ids, "npc_id '%s' is unique" % instance.npc_id)
		_assert_false(instance.display_name in seen_names, "display_name '%s' is unique" % instance.display_name)
		_assert_false(instance.dialogue_path.is_empty(), "npc '%s' has a dialogue_path" % instance.npc_id)

		seen_ids.append(instance.npc_id)
		seen_names.append(instance.display_name)

		instance.queue_free()

	player.queue_free()

func _load_dialogue(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var json_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or not parsed is Dictionary:
		return {}

	return parsed as Dictionary

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
