extends SceneTree

var _failures := 0
var _total := 0
var _passed := 0

func _initialize() -> void:
	# Defer test execution so the SceneTree is fully ready and physics is pumping.
	_run_tests.call_deferred()

func _run_tests() -> void:
	await physics_frame

	print("PHASE0_EXIT_TEST: START")

	# SceneTree --script mode does not load autoloads; instantiate them manually
	# so get_node("/root/GameState") and get_node("/root/SaveManager") resolve.
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		gs = load("res://scripts/systems/game_state.gd").new()
		gs.name = "GameState"
		root.add_child(gs)

	var sm := root.get_node_or_null("SaveManager")
	if sm == null:
		sm = load("res://scripts/systems/save_manager.gd").new()
		sm.name = "SaveManager"
		root.add_child(sm)

	var scene_router := root.get_node_or_null("SceneRouter")
	if scene_router == null:
		scene_router = load("res://scripts/systems/scene_router.gd").new()
		scene_router.name = "SceneRouter"
		root.add_child(scene_router)

	await _check_move()
	await _check_talk(gs)
	_check_save(sm)
	_check_mutate_load(gs, sm)
	await _check_scene_retain(gs, scene_router)

	_summary()

func _check_move() -> void:
	_total += 1
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	player.global_position = Vector2.ZERO
	var start_x := player.global_position.x

	Input.action_press("move_right")
	for i in range(30):
		await physics_frame
	Input.action_release("move_right")

	if player.global_position.x > start_x + 10.0:
		_passed += 1
		print("CHECK: MOVE PASS")
	else:
		_failures += 1
		print("CHECK: MOVE FAIL (x=" + str(player.global_position.x) + ")")

	player.queue_free()

func _check_talk(gs: Node) -> void:
	_total += 1
	var scene_a := load("res://scenes/core/placeholder_test_a.tscn") as PackedScene
	var current := scene_a.instantiate() as Node2D
	root.add_child(current)
	current_scene = current

	var npc_scene := load("res://scenes/npcs/npc.tscn") as PackedScene
	var npc := npc_scene.instantiate() as Npc
	npc.dialogue_path = "res://data/dialogue/dialogue_act1_abenthy_lesson.json"
	current.add_child(npc)

	npc.interact()
	await physics_frame

	var runner := npc._runner as DialogueRunner
	if runner == null:
		_failures += 1
		print("CHECK: TALK FAIL - DialogueRunner is null")
		current_scene = null
		current.queue_free()
		return

	if not runner._panel.visible:
		_failures += 1
		print("CHECK: TALK FAIL - dialogue UI is not visible")
		current_scene = null
		current.queue_free()
		return

	if runner.get_current_id() != "node_greeting":
		_failures += 1
		print("CHECK: TALK FAIL - current node is '" + runner.get_current_id() + "', expected 'node_greeting'")
		current_scene = null
		current.queue_free()
		return

	# Choose the first (curious) response on the greeting node.
	runner._on_choice(0)
	await physics_frame

	# Advance the auto-continue node that applies the lesson-seen flag.
	runner._on_choice(0)
	await physics_frame

	var relationship: float = gs.relationships.get("char_abenthy", 0.0)
	var has_lesson_flag: bool = gs.has_flag("flag_act1_abenthy_lesson_seen")

	if relationship == 1.0 and has_lesson_flag:
		_passed += 1
		print("CHECK: TALK PASS")
	else:
		_failures += 1
		print("CHECK: TALK FAIL (relationship=" + str(relationship) + ", has_lesson_flag=" + str(has_lesson_flag) + ")")

	current_scene = null
	current.queue_free()

func _check_save(sm: Node) -> void:
	_total += 1
	if sm.save_game(1):
		_passed += 1
		print("CHECK: SAVE PASS")
	else:
		_failures += 1
		print("CHECK: SAVE FAIL")

func _check_mutate_load(gs: Node, sm: Node) -> void:
	_total += 1
	var saved_money: int = gs.money
	var saved_relationship: float = gs.relationships.get("char_abenthy", 0.0)

	gs.money = 999
	gs.world_flags.erase("flag_act1_abenthy_lesson_seen")

	if not sm.load_game(1):
		_failures += 1
		print("CHECK: MUTATE+LOAD FAIL - load_game(1) returned false")
		return

	var money_ok: bool = gs.money == saved_money
	var flag_ok: bool = gs.has_flag("flag_act1_abenthy_lesson_seen")
	var relationship_ok: bool = gs.relationships.get("char_abenthy", 0.0) == saved_relationship

	if money_ok and flag_ok and relationship_ok:
		_passed += 1
		print("CHECK: MUTATE+LOAD PASS")
	else:
		_failures += 1
		print("CHECK: MUTATE+LOAD FAIL (money_ok=" + str(money_ok) + ", flag_ok=" + str(flag_ok) + ", relationship_ok=" + str(relationship_ok) + ")")

func _check_scene_retain(gs: Node, scene_router: Node) -> void:
	_total += 1

	# Allow any previously queued scenes to be freed before starting the transition check.
	await process_frame

	var scene_a := load("res://scenes/core/placeholder_test_a.tscn") as PackedScene
	var current := scene_a.instantiate() as Node2D
	root.add_child(current)
	current_scene = current

	scene_router.change_scene("res://scenes/core/placeholder_test_b.tscn")
	for i in range(90):
		await process_frame

	var current_name := "null"
	if current_scene != null:
		current_name = current_scene.name

	var flag_still_present: bool = gs.has_flag("flag_act1_abenthy_lesson_seen")

	if current_name == "PlaceholderTestB" and flag_still_present:
		_passed += 1
		print("CHECK: RETAIN ACROSS SCENES PASS")
	else:
		_failures += 1
		print("CHECK: RETAIN ACROSS SCENES FAIL (current=" + current_name + ", flag_still_present=" + str(flag_still_present) + ")")

func _summary() -> void:
	if _failures == 0:
		print("PHASE0_EXIT_TEST: PASS (" + str(_passed) + "/" + str(_total) + " checks)")
		quit(0)
	else:
		print("PHASE0_EXIT_TEST: FAIL (" + str(_passed) + "/" + str(_total) + " checks, " + str(_failures) + " failure(s))")
		quit(1)
