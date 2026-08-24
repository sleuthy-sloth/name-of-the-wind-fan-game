extends SceneTree

func _initialize() -> void:
	var total_checks := 0
	var passed_checks := 0

	# Check 1: input actions are registered
	var actions := ["move_up", "move_down", "move_left", "move_right", "interact", "pause"]
	for action in actions:
		total_checks += 1
		if InputMap.has_action(action):
			passed_checks += 1
			print("CHECK: InputMap.has_action(\"" + action + "\") PASS")
		else:
			print("ENGINE_SHELL_TEST: FAIL missing action " + action)
			quit(1)
			return

	# Check 2: player responds to input and moves
	total_checks += 1
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	player.global_position = Vector2.ZERO

	print("DEBUG: get_vector before press = " + str(Input.get_vector("move_left", "move_right", "move_up", "move_down")))
	Input.action_press("move_right")
	print("DEBUG: get_vector after press = " + str(Input.get_vector("move_left", "move_right", "move_up", "move_down")))
	for i in range(30):
		await physics_frame
	Input.action_release("move_right")

	if player.global_position.x > 10.0:
		passed_checks += 1
		print("CHECK: player movement PASS")
	else:
		print("ENGINE_SHELL_TEST: FAIL player did not move right (x=" + str(player.global_position.x) + ")")
		quit(1)
		return

	# Check 3: test scenes load
	total_checks += 1
	var scene_a := load("res://scenes/core/placeholder_test_a.tscn") as PackedScene
	var scene_b := load("res://scenes/core/placeholder_test_b.tscn") as PackedScene
	if scene_a != null and scene_b != null:
		passed_checks += 1
		print("CHECK: scene load PASS")
	else:
		print("ENGINE_SHELL_TEST: FAIL scene load failed")
		quit(1)
		return

	# Check 4: test scenes instantiate
	total_checks += 1
	var instance_a := scene_a.instantiate() as Node2D
	var instance_b := scene_b.instantiate() as Node2D
	if instance_a != null and instance_b != null:
		passed_checks += 1
		print("CHECK: scene instantiate PASS")
	else:
		print("ENGINE_SHELL_TEST: FAIL scene instantiate failed")
		quit(1)
		return

	# Check 5: scene transition via SceneRouter
	total_checks += 1
	root.remove_child(player)
	player.queue_free()

	root.add_child(instance_a)
	current_scene = instance_a

	await process_frame
	await process_frame

	var scene_router := root.get_node("SceneRouter")
	scene_router.change_scene("res://scenes/core/placeholder_test_b.tscn")

	for i in range(60):
		await process_frame

	var current_name := "null"
	if current_scene != null:
		current_name = current_scene.name

	if current_name == "PlaceholderTestB":
		passed_checks += 1
		print("CHECK: scene transition PASS")
	else:
		print("ENGINE_SHELL_TEST: FAIL scene transition (current=" + current_name + ")")
		quit(1)
		return

	print("ENGINE_SHELL_TEST: PASS (" + str(passed_checks) + "/" + str(total_checks) + " checks)")
	quit(0)
