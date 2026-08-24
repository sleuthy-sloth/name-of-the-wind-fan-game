class_name LdtkLoader
extends RefCounted

# Phase 0 minimal reader (IntGrid collision + Spawn only).
# Full tileset/entity support lands in Phase 1.


static func load_project(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		push_error("LdtkLoader: failed to read file: %s" % path)
		return {}

	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("LdtkLoader: failed to parse JSON: %s" % path)
		return {}

	var project := parsed as Dictionary
	if not project.has("jsonVersion"):
		push_error("LdtkLoader: missing jsonVersion in: %s" % path)
		return {}

	if not project.has("levels") or project["levels"] == null:
		push_error("LdtkLoader: missing levels in: %s" % path)
		return {}

	var levels = project["levels"]
	if not levels is Array or levels.size() < 1:
		push_error("LdtkLoader: project has no levels: %s" % path)
		return {}

	return project


static func build_level_node(project: Dictionary, level_index := 0, cell_size := 16) -> Node2D:
	var levels = project.get("levels", [])
	if level_index < 0 or level_index >= levels.size():
		push_error("LdtkLoader: level_index %d out of range" % level_index)
		return Node2D.new()

	var level = levels[level_index]
	if level == null or not level is Dictionary:
		push_error("LdtkLoader: level %d is not a dictionary" % level_index)
		return Node2D.new()

	var layer_instances = level.get("layerInstances", [])
	if not layer_instances is Array:
		push_error("LdtkLoader: layerInstances missing or invalid")
		return Node2D.new()

	var root := Node2D.new()
	root.name = level.get("identifier", "Level")

	var collision_layer: Dictionary = {}
	var entities_layer: Dictionary = {}
	for layer in layer_instances:
		if layer == null or not layer is Dictionary:
			continue
		var identifier: String = layer.get("identifier", "")
		if identifier == "Collision":
			collision_layer = layer
		elif identifier == "Entities":
			entities_layer = layer

	if collision_layer.is_empty():
		push_warning("LdtkLoader: no 'Collision' layer found")

	var static_body := StaticBody2D.new()
	static_body.name = "Collision"
	root.add_child(static_body)

	var csv_text: String = collision_layer.get("intGridCsv", "")
	var rows := csv_text.split("\n", false)
	var c_wid: int = collision_layer.get("__cWid", rows.size())
	var c_hei: int = collision_layer.get("__cHei", rows.size())
	var grid_size: int = collision_layer.get("__gridSize", cell_size)

	for y in range(min(rows.size(), c_hei)):
		var row := rows[y]
		var cells := row.split(",", false)
		for x in range(min(cells.size(), c_wid)):
			if cells[x].strip_edges() == "1":
				var shape := RectangleShape2D.new()
				shape.size = Vector2(grid_size, grid_size)

				var collision_shape := CollisionShape2D.new()
				collision_shape.shape = shape
				collision_shape.position = Vector2(
					x * grid_size + grid_size * 0.5,
					y * grid_size + grid_size * 0.5
				)
				static_body.add_child(collision_shape)

	var spawn := Vector2.ZERO
	var entity_instances = entities_layer.get("entityInstances", [])
	if entity_instances is Array:
		for entity in entity_instances:
			if entity == null or not entity is Dictionary:
				continue
			if entity.get("__identifier", "") == "Spawn":
				var px = entity.get("px", [0, 0])
				if px is Array and px.size() >= 2:
					spawn = Vector2(float(px[0]), float(px[1]))
				break

	root.set_meta("spawn_position", spawn)
	return root
