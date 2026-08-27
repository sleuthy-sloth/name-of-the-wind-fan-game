class_name ChronicleCanvas
extends Control

## A reusable, original storybook-style canvas for the opening presentation.
## Each illustration is built from engine primitives so it remains crisp at
## every viewport size and never relies on unlicensed artwork.

enum Illustration {
	TITLE_PAGE,
	WAYSTONE_FIRE,
	CARAVAN_DAWN,
}

@export var illustration: Illustration = Illustration.TITLE_PAGE

var _animation_enabled := true
var _elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		_animation_enabled = not bool(settings.get("reduce_motion"))


func _process(delta: float) -> void:
	if _animation_enabled:
		_elapsed += delta
		queue_redraw()


func set_illustration(value: Illustration) -> void:
	illustration = value
	queue_redraw()


func render_signature() -> Dictionary:
	return {
		"illustration": _illustration_name(),
		"layer_count": 6,
		"animation_enabled": _animation_enabled,
	}


func _draw() -> void:
	var canvas := Rect2(Vector2.ZERO, size)
	if canvas.size.x <= 0.0 or canvas.size.y <= 0.0:
		return

	# 1. Parchment
	draw_rect(canvas, Color("d4bb84"))
	# 2. Page edge
	draw_rect(canvas.grow(-12.0), Color("f0ddaa"), false, 4.0)
	# 3. Ink border
	draw_rect(canvas.grow(-28.0), Color("37271c"), false, 2.0)
	# 4. Scene silhouette
	_draw_scene_silhouette(canvas)
	# 5. Warm light pool
	_draw_warm_light(canvas)
	# 6. Ink detail
	_draw_ink_detail(canvas)


func _draw_scene_silhouette(canvas: Rect2) -> void:
	var horizon := canvas.position.y + canvas.size.y * 0.67
	var ink := Color("4b3929")
	match illustration:
		Illustration.TITLE_PAGE:
			var tree_x := canvas.position.x + canvas.size.x * 0.68
			draw_colored_polygon(PackedVector2Array([
				Vector2(canvas.position.x, horizon),
				Vector2(canvas.position.x + canvas.size.x * 0.17, horizon - canvas.size.y * 0.10),
				Vector2(canvas.position.x + canvas.size.x * 0.35, horizon - canvas.size.y * 0.04),
				Vector2(canvas.position.x + canvas.size.x * 0.5, horizon - canvas.size.y * 0.16),
				Vector2(canvas.position.x + canvas.size.x * 0.7, horizon - canvas.size.y * 0.05),
				Vector2(canvas.position.x + canvas.size.x, horizon),
				Vector2(canvas.position.x + canvas.size.x, canvas.end.y),
				Vector2(canvas.position.x, canvas.end.y),
			]), ink)
			draw_line(Vector2(tree_x, horizon), Vector2(tree_x, horizon - canvas.size.y * 0.22), ink, 8.0)
			draw_circle(Vector2(tree_x, horizon - canvas.size.y * 0.28), canvas.size.y * 0.09, ink)
		Illustration.WAYSTONE_FIRE:
			draw_rect(Rect2(canvas.position.x, horizon, canvas.size.x, canvas.end.y - horizon), ink)
			draw_rect(Rect2(canvas.get_center().x - 12.0, horizon - 70.0, 24.0, 70.0), ink)
		Illustration.CARAVAN_DAWN:
			draw_colored_polygon(PackedVector2Array([
				Vector2(canvas.position.x, horizon),
				Vector2(canvas.position.x + canvas.size.x * 0.25, horizon - canvas.size.y * 0.12),
				Vector2(canvas.position.x + canvas.size.x * 0.55, horizon - canvas.size.y * 0.04),
				Vector2(canvas.position.x + canvas.size.x * 0.8, horizon - canvas.size.y * 0.16),
				Vector2(canvas.end.x, horizon),
				Vector2(canvas.end.x, canvas.end.y),
				Vector2(canvas.position.x, canvas.end.y),
			]), ink)


func _draw_warm_light(canvas: Rect2) -> void:
	var pulse := 0.0
	if _animation_enabled:
		pulse = sin(_elapsed * 1.4) * 0.035
	var center := Vector2(canvas.get_center().x, canvas.position.y + canvas.size.y * 0.69)
	var radius: float = min(canvas.size.x, canvas.size.y) * (0.17 + pulse)
	draw_circle(center, radius, Color(0.96, 0.62, 0.24, 0.28))
	draw_circle(center, radius * 0.42, Color(1.0, 0.82, 0.48, 0.38))


func _draw_ink_detail(canvas: Rect2) -> void:
	var margin := 48.0
	var left := canvas.position.x + margin
	var right := canvas.end.x - margin
	var y := canvas.position.y + canvas.size.y * 0.18
	var ink := Color(0.22, 0.15, 0.11, 0.72)
	for ratio in [0.74, 0.58, 0.68]:
		draw_line(Vector2(left, y), Vector2(lerp(left, right, ratio), y), ink, 2.0)
		y += 13.0


func _illustration_name() -> String:
	match illustration:
		Illustration.TITLE_PAGE:
			return "title_page"
		Illustration.WAYSTONE_FIRE:
			return "waystone_fire"
		Illustration.CARAVAN_DAWN:
			return "caravan_dawn"
	return "title_page"
