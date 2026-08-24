extends SceneTree

func _initialize() -> void:
	_run_tests.call_deferred()

func _run_tests() -> void:
	await physics_frame

	var total_checks := 0
	var passed_checks := 0

	# Check 1: both LDtk projects load cleanly.
	total_checks += 1
	var caravan_project := LdtkLoader.load_project("res://maps/caravan_route.ldtk")
	var forest_project := LdtkLoader.load_project("res://maps/forest_campsite.ldtk")
	if caravan_project.has("jsonVersion") and forest_project.has("jsonVersion"):
		passed_checks += 1
		print("CHECK: LDtk load PASS")
	else:
		print("WORLD_TRAVERSAL_TEST: FAIL LDtk load failed")
		quit(1)
		return

	# Check 2: built level nodes have collision shapes.
	total_checks += 1
	var caravan_node := LdtkLoader.build_level_node(caravan_project)
	var forest_node := LdtkLoader.build_level_node(forest_project)
	var caravan_collision := caravan_node.get_node_or_null("Collision") as StaticBody2D
	var forest_collision := forest_node.get_node_or_null("Collision") as StaticBody2D
	if caravan_collision != null and caravan_collision.get_child_count() > 0 \
			and forest_collision != null and forest_collision.get_child_count() > 0:
		passed_checks += 1
		print("CHECK: collision shapes PASS")
	else:
		print("WORLD_TRAVERSAL_TEST: FAIL collision shapes (caravan=%d, forest=%d)" % [caravan_collision.get_child_count() if caravan_collision != null else -1, forest_collision.get_child_count() if forest_collision != null else -1])
		quit(1)
		return

	# Check 3: spawn_position meta exists inside level bounds.
	total_checks += 1
	var caravan_spawn: Variant = caravan_node.get_meta("spawn_position", Vector2.ZERO)
	var forest_spawn: Variant = forest_node.get_meta("spawn_position", Vector2.ZERO)
	var caravan_bounds := Rect2(0, 0, 320, 240)
	var forest_bounds := Rect2(0, 0, 320, 240)
	if caravan_spawn is Vector2 and forest_spawn is Vector2 \
			and caravan_bounds.has_point(caravan_spawn as Vector2) \
			and forest_bounds.has_point(forest_spawn as Vector2):
		passed_checks += 1
		print("CHECK: spawn position PASS")
	else:
		print("WORLD_TRAVERSAL_TEST: FAIL spawn position out of bounds (%s, %s)" % [str(caravan_spawn), str(forest_spawn)])
		quit(1)
		return

	caravan_node.queue_free()
	forest_node.queue_free()
	await process_frame

	# Check 4: SceneRouter.change_scene() lands on forest_campsite from caravan door.
	total_checks += 1
	var caravan_scene := load("res://scenes/world/caravan_route.tscn") as PackedScene
	if caravan_scene == null:
		print("WORLD_TRAVERSAL_TEST: FAIL caravan scene load failed")
		quit(1)
		return

	var caravan_instance := caravan_scene.instantiate() as Node2D
	root.add_child(caravan_instance)
	current_scene = caravan_instance
	for i in range(5):
		await process_frame

	var door := caravan_instance.get_node_or_null("Door") as Area2D
	if door == null:
		print("WORLD_TRAVERSAL_TEST: FAIL door not found in caravan scene")
		quit(1)
		return

	var body := CharacterBody2D.new()
	body.add_to_group(&"player")
	var body_shape := CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = Vector2(12, 16)
	body_shape.shape = body_rect
	body.add_child(body_shape)
	caravan_instance.add_child(body)
	body.global_position = door.global_position

	for i in range(10):
		await physics_frame
	for i in range(60):
		await process_frame

	var current_name := "null"
	if current_scene != null:
		current_name = current_scene.name

	if current_name == "ForestCampsite":
		passed_checks += 1
		print("CHECK: scene transition PASS")
	else:
		print("WORLD_TRAVERSAL_TEST: FAIL scene transition (current=%s)" % current_name)
		quit(1)
		return

	# Check 5: player node exists and moves under simulated input in campsite.
	total_checks += 1
	if current_scene == null:
		print("WORLD_TRAVERSAL_TEST: FAIL no current scene for player check")
		quit(1)
		return

	var campsite_player := current_scene.get_node_or_null("Player") as CharacterBody2D
	if campsite_player == null:
		print("WORLD_TRAVERSAL_TEST: FAIL player not found in campsite")
		quit(1)
		return

	var start_x := campsite_player.global_position.x
	Input.action_press("move_right")
	for i in range(30):
		await physics_frame
	Input.action_release("move_right")

	if campsite_player.global_position.x > start_x + 10.0:
		passed_checks += 1
		print("CHECK: campsite player movement PASS")
	else:
		print("WORLD_TRAVERSAL_TEST: FAIL campsite player did not move (x=%s)" % str(campsite_player.global_position.x))
		quit(1)
		return

	print("WORLD_TRAVERSAL_TEST: PASS (%d/%d checks)" % [passed_checks, total_checks])
	quit(0)
