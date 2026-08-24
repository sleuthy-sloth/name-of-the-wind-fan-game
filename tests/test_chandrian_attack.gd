extends SceneTree

var _failures := 0
var _passed := 0
var _total := 0

var _gs: Node = null
var _sm: Node = null
var _router: Node = null

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	print("CHANDRIAN_ATTACK_TEST: START")

	_setup_autoloads()
	_cleanup_save_slot()

	_test_json_structure()
	await _test_attack_sequence()
	await _test_aftermath_mode()
	_test_save_persistence()
	_cleanup_save_slot()

	_summary()

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

func _cleanup_save_slot() -> void:
	if _sm != null:
		_sm.delete_save(0)

func _test_json_structure() -> void:
	_total += 1
	var file := FileAccess.open("res://data/dialogue/dialogue_act1_chandrian_attack.json", FileAccess.READ)
	if file == null:
		_failures += 1
		print("CHECK: JSON STRUCTURE FAIL - could not open file")
		return
	var raw := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null or not parsed is Dictionary:
		_failures += 1
		print("CHECK: JSON STRUCTURE FAIL - invalid JSON")
		return

	var dict: Dictionary = parsed as Dictionary
	var beats: Variant = dict.get("beats")
	var aftermath: Variant = dict.get("aftermath_beats")

	if beats == null or not beats is Array or (beats as Array).size() < 8:
		_failures += 1
		print("CHECK: JSON STRUCTURE FAIL - expected >=8 beats, got %d" % [(beats as Array).size() if beats is Array else 0])
		return

	if aftermath == null or not aftermath is Array or (aftermath as Array).size() < 2:
		_failures += 1
		print("CHECK: JSON STRUCTURE FAIL - expected >=2 aftermath beats, got %d" % [(aftermath as Array).size() if aftermath is Array else 0])
		return

	_passed += 1
	print("CHECK: JSON STRUCTURE PASS")

func _test_attack_sequence() -> void:
	_total += 1
	var director := ChandrianAttack.new()
	director.name = "AttackDirector"
	root.add_child(director)

	director.start_sequence()

	var timeout := 600
	while timeout > 0 and not director.is_sequence_complete():
		await process_frame
		timeout -= 1

	if timeout == 0:
		_failures += 1
		print("CHECK: ATTACK SEQUENCE FAIL - timed out waiting for completion")
		director.queue_free()
		return

	var flag_set: bool = _gs.has_flag("chandrian_attack_occurred")
	var save_exists: bool = _sm.has_save(0)

	if flag_set and save_exists:
		_passed += 1
		print("CHECK: ATTACK SEQUENCE PASS")
	else:
		_failures += 1
		print("CHECK: ATTACK SEQUENCE FAIL (flag=%s, save=%s)" % [str(flag_set), str(save_exists)])

	director.queue_free()
	await _wait_for_router_idle()
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null

func _test_aftermath_mode() -> void:
	_total += 1
	var director := ChandrianAttack.new()
	director.name = "AftermathDirector"
	director.mode = "aftermath"
	root.add_child(director)

	director.start_sequence()

	var timeout := 600
	while timeout > 0 and not director.is_sequence_complete():
		await process_frame
		timeout -= 1

	if timeout == 0:
		_failures += 1
		print("CHECK: AFTERMATH MODE FAIL - timed out waiting for director completion")
		director.queue_free()
		return

	director.queue_free()

	timeout = 600
	while timeout > 0:
		await process_frame
		timeout -= 1
		if current_scene != null:
			var path: String = current_scene.scene_file_path
			if path == "res://scenes/ui/end_card.tscn":
				break

	var end_card_reached: bool = current_scene != null and current_scene.scene_file_path == "res://scenes/ui/end_card.tscn"
	var flag_set: bool = _gs.has_flag("vertical_slice_completed")

	if end_card_reached and flag_set:
		_passed += 1
		print("CHECK: AFTERMATH MODE PASS")
	else:
		_failures += 1
		print("CHECK: AFTERMATH MODE FAIL (end_card=%s, flag=%s)" % [str(end_card_reached), str(flag_set)])

	if current_scene != null:
		current_scene.queue_free()
		current_scene = null

func _test_save_persistence() -> void:
	_total += 1
	var saved_ok: bool = _sm.save_game(0)
	if not saved_ok:
		_failures += 1
		print("CHECK: SAVE PERSISTENCE FAIL - save_game(0) returned false")
		return

	root.remove_child(_gs)
	_gs.queue_free()
	await process_frame

	var fresh := load("res://scripts/systems/game_state.gd").new()
	fresh.name = "GameState"
	root.add_child(fresh)
	_gs = fresh

	var loaded: bool = _sm.load_game(0)
	var flag_survived: bool = _gs.has_flag("chandrian_attack_occurred")

	if loaded and flag_survived:
		_passed += 1
		print("CHECK: SAVE PERSISTENCE PASS")
	else:
		_failures += 1
		print("CHECK: SAVE PERSISTENCE FAIL (loaded=%s, flag=%s)" % [str(loaded), str(flag_survived)])

func _wait_for_router_idle() -> void:
	var timeout := 120
	while timeout > 0 and _router.is_transitioning:
		await process_frame
		timeout -= 1

func _summary() -> void:
	if _failures == 0:
		print("CHANDRIAN_ATTACK_TEST: PASS (%d/%d checks)" % [_passed, _total])
		quit(0)
	else:
		print("CHANDRIAN_ATTACK_TEST: FAIL (%d/%d checks, %d failure(s))" % [_passed, _total, _failures])
		quit(1)
