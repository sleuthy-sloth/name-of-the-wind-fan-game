class_name MapRenderer
extends Control

## MapRenderer
# Draws visited scenes as lit dots + edges between them. Unvisited scenes
# are shown as dim "fog of war" hints so the player can intuit where they
# haven't been yet. Recolor based on the Settings colorblind palette.

const DOT_RADIUS := 9.0
const RUMOR_RADIUS := 10.0
const POSITION_BOUNDS := Rect2(Vector2(0, 0), Vector2(1000, 600))

func _draw() -> void:
	var map := get_node_or_null("/root/ExplorationMap")
	if map == null:
		return
	var visited: Array = map.visited_scenes()
	var edges: Array = map.edges()
	var size := get_size()
	var origin := Vector2(60, 60)
	var span := Vector2(max(1.0, POSITION_BOUNDS.size.x), max(1.0, POSITION_BOUNDS.size.y))
	var scale_to_view := _scale_to_view(size, origin)
	var backdrop := _cb(Color(0.18, 0.16, 0.13, 0.85))
	draw_rect(Rect2(origin - Vector2(8, 8), span * scale_to_view + Vector2(16, 16)), backdrop)

	# Edges (drawn first so dots sit on top).
	for e: Dictionary in edges:
		var from_pos := _project(map.scene_position(str(e.get("from", ""))), origin, span, scale_to_view)
		var to_pos := _project(map.scene_position(str(e.get("to", ""))), origin, span, scale_to_view)
		if from_pos == Vector2.ZERO or to_pos == Vector2.ZERO:
			continue
		draw_line(from_pos, to_pos, _cb(Color(0.85, 0.65, 0.3)), 2.0)

	# Visited nodes.
	for id in visited:
		var pos := _project(map.scene_position(id), origin, span, scale_to_view)
		if pos == Vector2.ZERO:
			continue
		draw_circle(pos, DOT_RADIUS, _cb(Color(0.95, 0.78, 0.42)))
		draw_circle(pos, DOT_RADIUS - 3.0, _cb(Color(0.25, 0.12, 0.05)))

	# Visit hints: outlines for unvisited but known scenes.
	var all_ids: Array = map.all_known_scenes()
	for id in all_ids:
		if visited.has(id):
			continue
		var pos := _project(map.scene_position(id), origin, span, scale_to_view)
		if pos == Vector2.ZERO:
			continue
		draw_circle(pos, RUMOR_RADIUS, _cb(Color(0.32, 0.28, 0.24, 0.6)))

	# Visited labels.
	for id in visited:
		var pos := _project(map.scene_position(id), origin, span, scale_to_view)
		if pos == Vector2.ZERO:
			continue
		var label: String = map.scene_display_name(id)
		draw_string(get_theme_default_font(), pos + Vector2(14, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)

func _scale_to_view(view_size: Vector2, origin: Vector2) -> float:
	var avail_w := view_size.x - origin.x * 2.0
	var avail_h := view_size.y - origin.y * 2.0
	var sx := avail_w / POSITION_BOUNDS.size.x
	var sy := avail_h / POSITION_BOUNDS.size.y
	return minf(sx, sy)

func _project(world_pos: Vector2, origin: Vector2, span: Vector2, scale_to_view: float) -> Vector2:
	if world_pos == Vector2.ZERO:
		return Vector2.ZERO
	return origin + world_pos * scale_to_view

## Apply Settings.colorblind_adjusted when present; return `base` otherwise.
func _cb(base: Color) -> Color:
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("colorblind_adjusted"):
		return settings.colorblind_adjusted(base)
	return base
