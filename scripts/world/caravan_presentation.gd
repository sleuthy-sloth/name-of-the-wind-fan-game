class_name CaravanPresentation
extends Node2D

## Original, procedural caravan dressing. This node owns no physics, input,
## gameplay metadata, or state: it is strictly a visual companion to the road.

var _animation_enabled := true
var _elapsed := 0.0


func _ready() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		_animation_enabled = not bool(settings.get("reduce_motion"))
	queue_redraw()


func _process(delta: float) -> void:
	if not _animation_enabled:
		return
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	_draw_shadows()
	_draw_canopy()
	_draw_wagons()
	_draw_tents()
	_draw_campfire()
	_draw_atmosphere()


func _draw_shadows() -> void:
	var shade := Color("24333a", 0.32)
	_draw_ellipse(Vector2(244, 300), Vector2(192, 28), shade)
	_draw_ellipse(Vector2(484, 348), Vector2(164, 24), shade)
	_draw_ellipse(Vector2(78, 152), Vector2(118, 18), shade)


func _draw_canopy() -> void:
	var trunk := Color("503a2c")
	var leaf_dark := Color("18332f")
	var leaf_mid := Color("245044")
	for tree in [Vector2(42, 40), Vector2(148, 56), Vector2(580, 48), Vector2(676, 136)]:
		draw_rect(Rect2(tree + Vector2(-7, 12), Vector2(14, 68)), trunk)
		draw_circle(tree, 42.0, leaf_dark)
		draw_circle(tree + Vector2(20, 14), 30.0, leaf_mid)
		draw_circle(tree + Vector2(-22, 17), 25.0, leaf_mid)


func _draw_wagons() -> void:
	var wood := Color("81543a")
	var rim := Color("3d2b25")
	for wagon in [Vector2(214, 258), Vector2(452, 306)]:
		draw_rect(Rect2(wagon + Vector2(-48, -22), Vector2(96, 38)), wood)
		draw_line(wagon + Vector2(-52, 17), wagon + Vector2(54, 17), rim, 5.0)
		for wheel_x in [-30.0, 30.0]:
			draw_circle(wagon + Vector2(wheel_x, 23), 15.0, rim)
			draw_circle(wagon + Vector2(wheel_x, 23), 5.0, Color("b88356"))
		var canopy := PackedVector2Array([
			wagon + Vector2(-44, -24), wagon + Vector2(-23, -52),
			wagon + Vector2(28, -52), wagon + Vector2(46, -24),
		])
		draw_colored_polygon(canopy, Color("d7b67c"))


func _draw_tents() -> void:
	for tent in [Vector2(114, 296), Vector2(348, 188), Vector2(590, 282)]:
		var canvas := PackedVector2Array([
			tent + Vector2(-48, 24), tent + Vector2(0, -34),
			tent + Vector2(48, 24),
		])
		draw_colored_polygon(canvas, Color("9b7756"))
		draw_line(tent + Vector2(0, -34), tent + Vector2(0, 24), Color("4c382d"), 3.0)
		draw_rect(Rect2(tent + Vector2(-11, 5), Vector2(22, 19)), Color("4c382d"))


func _draw_campfire() -> void:
	var center := Vector2(302, 332)
	var flicker := sin(_elapsed * 4.0) * 2.0 if _animation_enabled else 0.0
	draw_circle(center, 44.0 + flicker, Color(0.95, 0.45, 0.14, 0.14))
	draw_line(center + Vector2(-20, 10), center + Vector2(21, -10), Color("5d3828"), 7.0)
	draw_line(center + Vector2(-20, -10), center + Vector2(21, 10), Color("5d3828"), 7.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-13, 10), center + Vector2(0, -30 - flicker), center + Vector2(14, 10),
	]), Color("e56c28"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-6, 8), center + Vector2(1, -14 - flicker), center + Vector2(8, 8),
	]), Color("ffd46f"))


func _draw_atmosphere() -> void:
	var drift := sin(_elapsed * 0.65) * 7.0 if _animation_enabled else 0.0
	for leaf in [Vector2(183, 106), Vector2(414, 154), Vector2(638, 218)]:
		draw_circle(leaf + Vector2(drift, 0), 3.0, Color("b8a666", 0.65))
	for ember in [Vector2(290, 286), Vector2(318, 274), Vector2(328, 301)]:
		draw_circle(ember + Vector2(0, -abs(sin(_elapsed * 2.0)) * 12.0), 2.5, Color("ffd46f", 0.82))


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 17:
		var angle := TAU * float(index) / 16.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
