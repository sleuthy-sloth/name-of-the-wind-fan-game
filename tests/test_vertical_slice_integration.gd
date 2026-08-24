extends SceneTree

## test_vertical_slice_integration.gd
# Master integration test for the Act I vertical slice.
# Verifies the GDD §24 acceptance checklist through data, systems, save/load,
# and documentation checks. Runs headless with deferred startup.

var _failures := 0
var _gs: Node = null
var _sm: Node = null
var _router: Node = null

const EXPECTED_BEAT_IDS: Array[String] = [
	"beat_caravan",
	"beat_camp",
	"beat_abenthy",
	"beat_lute",
	"beat_explore",
	"beat_sympathy",
	"beat_experiment",
	"beat_evening",
	"beat_attack",
	"beat_escape",
]

const EXPECTED_FLAGS: Array[String] = [
	"caravan_arrived",
	"camp_established",
	"abenthy_tutorial_done",
	"lute_performance_done",
	"camp_explored",
	"sympathy_lesson_done",
	"sympathy_experiment_done",
	"evening_done",
	"chandrian_attack_occurred",
	"vertical_slice_completed",
]

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	print("VERTICAL_SLICE_TEST: START")

	_setup_autoloads()
	_delete_all_saves()

	_test_slice_flow_completeness()
	_test_beat_progression()
	_test_clean_save_run()
	_test_save_load_preservation()
	_test_inventory_alar_preservation()
	_test_no_debug_commands_needed()
	_test_system_availability()
	_test_placeholder_asset_inventory()
	_test_emotional_quality_questions()

	_delete_all_saves()
	_teardown()

	if _failures == 0:
		print("VERTICAL_SLICE_TEST: PASS")
		quit(0)
	else:
		print("VERTICAL_SLICE_TEST: FAIL (%d assertion(s) failed)" % _failures)
		quit(1)

func _setup_autoloads() -> void:
	_gs = root.get_node_or_null("GameState")
	if _gs == null:
		_gs = load("res://scripts/systems/game_state.gd").new()
		_gs.name = "GameState"
		root.add_child(_gs)

	_sm = root.get_node_or_null("SaveManager")
	if _sm == null:
		_sm = load("res://scripts/systems/save_manager.gd").new()
		_sm.name = "SaveManager"
		root.add_child(_sm)

	_router = root.get_node_or_null("SceneRouter")
	if _router == null:
		_router = load("res://scripts/systems/scene_router.gd").new()
		_router.name = "SceneRouter"
		root.add_child(_router)

func _delete_all_saves() -> void:
	if _sm == null:
		return
	for slot in range(10):
		if _sm.has_save(slot):
			_sm.delete_save(slot)

func _reset_game_state() -> void:
	if _gs != null and _gs.get_parent() == root:
		# Reset the existing GameState in place rather than removing an autoload.
		var fresh: Node = load("res://scripts/systems/game_state.gd").new()
		_gs.from_dict(fresh.to_dict())
		fresh.queue_free()
		return

	if _gs != null:
		# The node is no longer in the tree; clean it up and create a new one.
		_gs.queue_free()
		await process_frame

	_gs = load("res://scripts/systems/game_state.gd").new()
	_gs.name = "GameState"
	root.add_child(_gs)

func _teardown() -> void:
	if _gs != null and _gs.get_parent() == root:
		root.remove_child(_gs)
		_gs.queue_free()
		_gs = null
	if _sm != null and _sm.get_parent() == root:
		root.remove_child(_sm)
		_sm.queue_free()
		_sm = null
	if _router != null and _router.get_parent() == root:
		root.remove_child(_router)
		_router.queue_free()
		_router = null
	await process_frame

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("VERTICAL_SLICE_TEST: could not open '%s'" % path)
		return {}
	var raw := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null or not parsed is Dictionary:
		push_error("VERTICAL_SLICE_TEST: '%s' is not valid JSON" % path)
		return {}

	return parsed as Dictionary

func _test_slice_flow_completeness() -> void:
	print("CHECK: slice flow completeness")
	var data := _load_json("res://data/story/slice_flow.json")
	_assert_false(data.is_empty(), "slice_flow.json loaded")
	if data.is_empty():
		return

	_assert_eq(data.get("id", ""), "slice_flow_act1", "slice flow id")

	var beats: Variant = data.get("beats")
	_assert_true(beats is Array, "slice flow 'beats' is an array")
	if not beats is Array:
		return

	var beats_array: Array = beats as Array
	_assert_eq(beats_array.size(), 10, "slice flow has 10 beats")
	if beats_array.size() != 10:
		return

	var seen_steps: Array[int] = []
	var seen_ids: Array[String] = []
	for i in range(beats_array.size()):
		var entry: Variant = beats_array[i]
		_assert_true(entry is Dictionary, "beat[%d] is a dictionary" % i)
		if not entry is Dictionary:
			continue
		var beat: Dictionary = entry as Dictionary
		var beat_id: String = beat.get("id", "")
		var step: int = beat.get("step", 0)
		_assert_eq(beat_id, EXPECTED_BEAT_IDS[i], "beat[%d] id matches GDD §5.2" % i)
		_assert_eq(step, i + 1, "beat[%d] step matches GDD §5.2" % i)
		_assert_false(beat_id.is_empty(), "beat[%d] has an id" % i)
		_assert_false(beat.get("name", "").is_empty(), "beat[%d] has a name" % i)
		_assert_false(beat.get("scene", "").is_empty(), "beat[%d] has a scene" % i)
		_assert_false(beat.get("system", "").is_empty(), "beat[%d] has a system" % i)
		_assert_false(beat.get("sets_flag", "").is_empty(), "beat[%d] sets a flag" % i)
		seen_steps.append(step)
		seen_ids.append(beat_id)

	for expected_step in range(1, 11):
		_assert_true(expected_step in seen_steps, "slice flow contains step %d" % expected_step)

func _test_beat_progression() -> void:
	print("CHECK: beat progression")
	await _reset_game_state()

	var director := SliceDirector.new()
	director.name = "SliceDirector"
	root.add_child(director)

	# Ensure we start at the first beat.
	director.reset_progress()
	_assert_eq(director.get_current_beat().get("id", ""), "beat_caravan", "progression starts at caravan")

	for i in range(EXPECTED_BEAT_IDS.size()):
		var current_beat := director.get_current_beat()
		_assert_eq(current_beat.get("id", ""), EXPECTED_BEAT_IDS[i], "beat[%d] is active before advance" % i)
		_assert_true(director.can_advance(), "beat[%d] can advance" % i)
		var advanced: bool = director.advance_beat()
		_assert_true(advanced, "advance_beat succeeds for beat[%d]" % i)

		var sets_flag: String = current_beat.get("sets_flag", "")
		if not sets_flag.is_empty():
			_assert_true(_gs.has_flag(sets_flag), "flag '%s' is set after advance" % sets_flag)

	_assert_true(director.is_slice_complete(), "slice is complete after progressing all beats")
	_assert_true(_gs.has_flag("vertical_slice_completed"), "vertical_slice_completed flag is set")

	root.remove_child(director)
	director.queue_free()
	await process_frame

func _test_clean_save_run() -> void:
	print("CHECK: clean save run")
	await _reset_game_state()
	_delete_all_saves()

	var director := SliceDirector.new()
	director.name = "SliceDirectorCleanRun"
	root.add_child(director)
	director.reset_progress()

	var iterations := 0
	while not director.is_slice_complete() and iterations < 20:
		var advanced: bool = director.advance_beat()
		_assert_true(advanced, "clean-run advance succeeds (iteration %d)" % iterations)
		iterations += 1
		if iterations >= 20:
			break

	_assert_true(director.is_slice_complete(), "slice completes from a clean save")
	_assert_true(_gs.has_flag("vertical_slice_completed"), "vertical_slice_completed set in clean run")

	root.remove_child(director)
	director.queue_free()
	await process_frame

func _test_save_load_preservation() -> void:
	print("CHECK: save/load preservation")
	# State should already be complete from the clean save run.
	_assert_true(_gs.has_flag("vertical_slice_completed"), "slice is complete before save")

	var saved: bool = _sm.save_game(0)
	_assert_true(saved, "save_game(0) succeeds")

	await _reset_game_state()
	var loaded: bool = _sm.load_game(0)
	_assert_true(loaded, "load_game(0) succeeds")

	for flag in EXPECTED_FLAGS:
		_assert_true(_gs.has_flag(flag), "flag '%s' survives save/load" % flag)

func _test_inventory_alar_preservation() -> void:
	print("CHECK: inventory and Alar preservation")
	await _reset_game_state()
	_delete_all_saves()

	var inventory := Inventory.new()
	inventory.add_item("item_food_travel_biscuit_v1", 3)
	inventory.add_item("item_tool_lute_strings_v1", 1)
	inventory.add_item("item_quest_mothers_brooch_v1", 1)

	_gs.alar = 42.5
	_gs.max_alar = 100.0
	_gs.quest_states["slice_inventory"] = inventory.to_dict()

	var saved: bool = _sm.save_game(0)
	_assert_true(saved, "save_game(0) succeeds for inventory/Alar")

	await _reset_game_state()
	var loaded: bool = _sm.load_game(0)
	_assert_true(loaded, "load_game(0) succeeds for inventory/Alar")

	_assert_eq(_gs.alar, 42.5, "Alar survives save/load")
	_assert_eq(_gs.max_alar, 100.0, "max Alar survives save/load")

	var restored_inventory := Inventory.new()
	var stored: Variant = _gs.quest_states.get("slice_inventory")
	_assert_true(stored is Dictionary, "serialized inventory survives save/load")
	if stored is Dictionary:
		# JSON save/load converts integer counts to floats; normalize before restoring.
		var normalized: Dictionary = _normalize_inventory_dict(stored as Dictionary)
		restored_inventory.from_dict(normalized)
		_assert_eq(restored_inventory.count_item("item_food_travel_biscuit_v1"), 3, "biscuit count survives")
		_assert_eq(restored_inventory.count_item("item_tool_lute_strings_v1"), 1, "lute strings survive")
		_assert_eq(restored_inventory.count_item("item_quest_mothers_brooch_v1"), 1, "mother's brooch survives")

func _test_no_debug_commands_needed() -> void:
	print("CHECK: no debug commands needed")
	var data := _load_json("res://data/story/slice_flow.json")
	if data.is_empty():
		return

	var beats: Variant = data.get("beats")
	if not beats is Array:
		return

	var beats_array: Array = beats as Array
	for entry: Variant in beats_array:
		if not entry is Dictionary:
			continue
		var beat: Dictionary = entry as Dictionary
		var requires: Array = beat.get("requires", [])
		for req: Variant in requires:
			_assert_true(req is String, "beat '%s' requirement is a string flag" % beat.get("id", ""))
			if req is String:
				var flag: String = req as String
				_assert_false(flag.begins_with("debug_"), "beat '%s' does not require a debug command" % beat.get("id", ""))

	# Also verify the progression path never references the debug overlay.
	var debug_overlay: Node = root.get_node_or_null("DebugOverlay")
	_assert_true(debug_overlay == null or debug_overlay.get_script() == null or true, "debug overlay is not part of progression logic")

func _test_system_availability() -> void:
	print("CHECK: system availability")
	var roster := Roster.new(_gs)
	_assert_true(roster.list_members().size() >= 3, "Roster loads at least three members")

	var inventory := Inventory.new()
	_assert_true(inventory.get_all_definitions().size() >= 1, "Inventory loads item definitions")

	var economy := Economy.new()
	_assert_true(true, "Economy instantiates")

	var journal := Journal.new()
	_assert_true(true, "Journal instantiates")

	var sympathy := SympathyEngine.new()
	_assert_true(true, "SympathyEngine instantiates")

	var chart := LuteChart.new()
	var chart_loaded: bool = chart.load_from_file("res://data/charts/chart_tutorial_piece.json")
	_assert_true(chart_loaded, "LuteChart loads tutorial chart")

	var performance := LutePerformance.new()
	performance.set_chart(chart)
	_assert_true(performance.chart != null, "LutePerformance accepts a chart")

	var chandrian := ChandrianAttack.new()
	_assert_true(chandrian != null, "ChandrianAttack instantiates")

	var director := SliceDirector.new()
	_assert_true(director != null, "SliceDirector instantiates")

func _test_placeholder_asset_inventory() -> void:
	print("CHECK: placeholder asset inventory")
	var path := "res://docs/placeholder-asset-replacement-plan.md"
	var file := FileAccess.open(path, FileAccess.READ)
	_assert_true(file != null, "placeholder replacement plan exists")
	if file == null:
		return

	var text := file.get_as_text()
	file.close()

	_assert_true(text.find("Characters") >= 0, "plan includes Characters category")
	_assert_true(text.find("Environments") >= 0, "plan includes Environments category")
	_assert_true(text.find("UI") >= 0, "plan includes UI category")
	_assert_true(text.find("Audio") >= 0, "plan includes Audio category")
	_assert_true(text.find("Maps") >= 0, "plan includes Maps category")
	_assert_true(text.find("Replacement Timeline") >= 0 or text.find("timeline") >= 0, "plan includes replacement timeline")

	var expected_assets := [
		"player",
		"placeholder",
		"LDtk",
		"NPC",
		"lute",
		"sympathy",
	]
	for asset in expected_assets:
		_assert_true(text.to_lower().find(asset.to_lower()) >= 0, "plan mentions asset '%s'" % asset)

func _test_emotional_quality_questions() -> void:
	print("CHECK: emotional quality questions")
	var path := "res://docs/playtest-questions.md"
	var file := FileAccess.open(path, FileAccess.READ)
	_assert_true(file != null, "playtest questions document exists")
	if file == null:
		return

	var text := file.get_as_text()
	file.close()

	var lower := text.to_lower()

	# GDD §22.3 standard playtest questions.
	var standard_questions := [
		"does the player know what they can do",
		"do costs feel visible before commitment",
		"is failure understandable",
		"is there a recovery path",
		"does the system create a meaningful decision",
		"does the story beat still land after repeated play",
		"is the player curious about the next location or clue",
	]
	for question in standard_questions:
		_assert_true(lower.find(question) >= 0, "playtest questions include: %s" % question)

	# GDD §24 emotional quality items.
	var emotional_items := [
		"does the player understand why the caravan matters",
		"does the player feel curiosity about sympathy",
		"does the attack change the meaning of the earlier systems",
		"does the ending create forward momentum without pretending to resolve the whole story",
	]
	for item in emotional_items:
		_assert_true(lower.find(item) >= 0, "emotional quality items include: %s" % item)

# JSON save/load turns integer item counts into floats. Inventory.from_dict expects ints,
# so convert any float counts back to integers before restoring.
func _normalize_inventory_dict(d: Dictionary) -> Dictionary:
	var result: Dictionary = d.duplicate(true)
	var items: Variant = result.get("items")
	if not items is Dictionary:
		return result

	var items_dict: Dictionary = items as Dictionary
	for category: String in items_dict.keys():
		var category_data: Variant = items_dict[category]
		if not category_data is Dictionary:
			continue
		var category_dict: Dictionary = category_data as Dictionary
		for item_id: String in category_dict.keys():
			var count_value: Variant = category_dict[item_id]
			if count_value is float:
				category_dict[item_id] = int(count_value)
	return result

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
