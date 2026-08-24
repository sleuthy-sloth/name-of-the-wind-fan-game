extends SceneTree

func _initialize() -> void:
	_run_tests.call_deferred()

func _run_tests() -> void:
	await physics_frame

	var total_checks := 0
	var passed_checks := 0

	# Check 1: LDtk project loads and has expected structure.
	total_checks += 1
	var project := LdtkLoader.load_project("res://maps/test_caravan_blockout.ldtk")
	if project.has("jsonVersion") and project.get("levels", []).size() >= 1:
		passed_checks += 1
		print("CHECK: LDtk load PASS")
	else:
		print("PIPELINE_TEST: FAIL LDtk load failed")
		quit(1)
		return

	# Check 2: level node builds with collision bodies and spawn meta.
	total_checks += 1
	var node := LdtkLoader.build_level_node(project)
	var collision := node.get_node_or_null("Collision") as StaticBody2D
	if collision != null and collision.get_child_count() >= 50:
		passed_checks += 1
		print("CHECK: collision bodies PASS")
	else:
		var count := 0
		if collision != null:
			count = collision.get_child_count()
		print("PIPELINE_TEST: FAIL collision bodies (count=%d)" % count)
		quit(1)
		return

	total_checks += 1
	var spawn_position: Variant = node.get_meta("spawn_position", Vector2.ZERO)
	if spawn_position is Vector2:
		var bounds := Rect2(0, 0, 320, 192)
		if bounds.has_point(spawn_position):
			passed_checks += 1
			print("CHECK: spawn position PASS")
		else:
			print("PIPELINE_TEST: FAIL spawn position out of bounds (%s)" % str(spawn_position))
			quit(1)
			return
	else:
		print("PIPELINE_TEST: FAIL spawn position is not Vector2")
		quit(1)
		return

	# Check 3: placeholder sprite exists with correct size.
	total_checks += 1
	var texture := load("res://art/sprites/kvothe_placeholder_sheet.png") as Texture2D
	if texture != null and texture.get_size() == Vector2(64, 32):
		passed_checks += 1
		print("CHECK: placeholder sprite PASS")
	else:
		var size_text := "null"
		if texture != null:
			size_text = str(texture.get_size())
		print("PIPELINE_TEST: FAIL placeholder sprite (size=%s)" % size_text)
		quit(1)
		return

	node.queue_free()
	await process_frame

	print("PIPELINE_TEST: PASS (%d/%d checks)" % [passed_checks, total_checks])
	quit(0)
