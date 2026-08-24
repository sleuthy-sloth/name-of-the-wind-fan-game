class_name LdtkLoader
extends RefCounted

# Phase 0/1 reader: IntGrid collision, Spawn/Door/Interaction entities, and
# data layers (Decoration, Foreground, Lighting). Keeps Phase 0 API intact.


static func load_project(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		push_error("LdtkLoader: failed to read file: %s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(text)
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

	var levels: Variant = project["levels"]
	if not levels is Array or levels.size() < 1:
		push_error("LdtkLoader: project has no levels: %s" % path)
		return {}

	return project


static func build_level_node(project: Dictionary, level_index := 0, cell_size := 16) -> Node2D:
	var levels: Variant = project.get("levels", [])
	if level_index < 0 or level_index >= levels.size():
		push_error("LdtkLoader: level_index %d out of range" % level_index)
		return Node2D.new()

	var level: Variant = levels[level_index]
	if level == null or not level is Dictionary:
		push_error("LdtkLoader: level %d is not a dictionary" % level_index)
		return Node2D.new()

	var layer_instances: Variant = level.get("layerInstances", [])
	if not layer_instances is Array:
		push_error("LdtkLoader: layerInstances missing or invalid")
		return Node2D.new()

	var root := Node2D.new()
	root.name = level.get("identifier", "Level")

	var collision_layer: Dictionary = {}
	var entities_layer: Dictionary = {}
	var decoration_layer: Dictionary = {}
	var foreground_layer: Dictionary = {}
	var lighting_layer: Dictionary = {}

	for layer: Variant in layer_instances:
		if layer == null or not layer is Dictionary:
			continue
		var identifier: String = layer.get("identifier", "")
		match identifier:
			"Collision":
				collision_layer = layer
			"Entities":
				entities_layer = layer
			"Decoration":
				decoration_layer = layer
			"Foreground":
				foreground_layer = layer
			"Lighting":
				lighting_layer = layer

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

	root.set_meta("decorations", _read_data_cells(decoration_layer, grid_size))
	root.set_meta("foreground", _read_data_cells(foreground_layer, grid_size))
	root.set_meta("lighting", _read_data_cells(lighting_layer, grid_size))

	var spawn := Vector2.ZERO
	var doors: Array[Dictionary] = []
	var interactions: Array[Dictionary] = []

	var entity_instances: Variant = entities_layer.get("entityInstances", [])
	if entity_instances is Array:
		for entity: Variant in entity_instances:
			if entity == null or not entity is Dictionary:
				continue
			var entity_id: String = entity.get("__identifier", "")
			var px: Variant = entity.get("px", [0, 0])
			if not px is Array or px.size() < 2:
				continue
			var pos := Vector2(float(px[0]), float(px[1]))
			match entity_id:
				"Spawn":
					spawn = pos
				"Door":
					doors.append({"id": "door_%d" % doors.size(), "position": pos})
				"Interaction":
					interactions.append({"id": "interaction_%d" % interactions.size(), "position": pos})

	root.set_meta("spawn_position", spawn)
	root.set_meta("doors", doors)
	root.set_meta("interactions", interactions)
	return root


static func _read_data_cells(layer: Dictionary, grid_size: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if layer.is_empty():
		return out

	var csv_text: String = layer.get("intGridCsv", "")
	var rows := csv_text.split("\n", false)
	var c_wid: int = layer.get("__cWid", rows.size())
	var c_hei: int = layer.get("__cHei", rows.size())

	for y in range(min(rows.size(), c_hei)):
		var row := rows[y]
		var cells := row.split(",", false)
		for x in range(min(cells.size(), c_wid)):
			if cells[x].strip_edges() == "1":
				out.append({
					"grid": Vector2i(x, y),
					"position": Vector2(
						x * grid_size + grid_size * 0.5,
						y * grid_size + grid_size * 0.5
					)
				})
	return out
