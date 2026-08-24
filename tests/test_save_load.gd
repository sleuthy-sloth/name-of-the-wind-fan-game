extends SceneTree

var _failures: int = 0

func _init() -> void:
	# Defer test execution so the SceneTree is fully ready.
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("SAVE_LOAD_TEST: START")

	# Autoloads may already be registered; prefer them, otherwise instantiate manually.
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = load("res://scripts/systems/game_state.gd").new()
		gs.name = "GameState"
		root.add_child(gs)

	var sm = root.get_node_or_null("SaveManager")
	if sm == null:
		sm = load("res://scripts/systems/save_manager.gd").new()
		sm.name = "SaveManager"
		root.add_child(sm)

	_test_defaults(gs)
	_test_round_trip(gs)
	_test_save_load(gs, sm)
	_test_corrupt_load(gs, sm)

	if _failures == 0:
		print("SAVE_LOAD_TEST: PASS")
		quit(0)
	else:
		print("SAVE_LOAD_TEST: FAIL (%d assertion(s) failed)" % _failures)
		quit(1)

func _test_defaults(gs: Node) -> void:
	_assert_eq(gs.act, 1, "default act")
	_assert_eq(gs.alar, 100.0, "default alar")
	_assert_eq(gs.money, 0, "default money")

func _test_round_trip(gs: Node) -> void:
	gs.act = 2
	gs.day = 3
	gs.time_block = "evening"
	gs.alar = 42.5
	gs.money = 77
	gs.set_flag("flag_test")
	gs.relationships = {"char_abenthy": 1.5}

	var data = gs.to_dict()
	var fresh = load("res://scripts/systems/game_state.gd").new()
	fresh.from_dict(data)

	_assert_eq(fresh.act, 2, "round-trip act")
	_assert_eq(fresh.day, 3, "round-trip day")
	_assert_eq(fresh.time_block, "evening", "round-trip time_block")
	_assert_eq(fresh.alar, 42.5, "round-trip alar")
	_assert_eq(fresh.money, 77, "round-trip money")
	_assert_true(fresh.has_flag("flag_test"), "round-trip flag")
	_assert_eq(fresh.relationships.get("char_abenthy"), 1.5, "round-trip relationships")

func _test_save_load(gs: Node, sm: Node) -> void:
	# State already mutated from round-trip test.
	_assert_true(sm.save_game(1), "save_game returns true")
	_assert_true(sm.has_save(1), "has_save returns true after save")

	gs.money = 999
	gs.set_flag("temp_flag")

	_assert_true(sm.load_game(1), "load_game returns true")
	_assert_eq(gs.money, 77, "money restored from save")
	_assert_true(gs.has_flag("flag_test"), "original flag restored")
	_assert_false(gs.has_flag("temp_flag"), "post-save mutation reverted")

func _test_corrupt_load(gs: Node, sm: Node) -> void:
	var path: String = sm.slot_path(1)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("this is not json {{")
		file.close()
	else:
		push_error("Failed to write corrupt save")
		_failures += 1
		return

	var result = sm.load_game(1)
	_assert_false(result, "corrupt save returns false")

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
