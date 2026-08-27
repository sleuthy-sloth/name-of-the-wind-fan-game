class_name WaystoneInteriorPresentation
extends Node2D

## OpenRTP-backed Waystone interior dressing. Visual-only: no collision,
## interaction, routing, or save state lives here.

const ATLAS := preload("res://art/tilesets/openrtp/interior.png")
const TILE := 16.0
const FLOOR := Rect2(112, 32, 16, 16)
const WALL := Rect2(192, 32, 16, 16)
const RUG := Rect2(176, 176, 32, 32)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# 34×22 tiles match waystone_inn_interior.ldtk's 544×352 footprint.
	for y in range(22):
		for x in range(34):
			var tile := WALL if x == 0 or y == 0 or x == 33 or y == 21 else FLOOR
			draw_texture_rect_region(ATLAS, Rect2(x * TILE, y * TILE, TILE, TILE), tile)
	# Hearth, rug, bar and shelving establish recognizable inn zones.
	draw_texture_rect_region(ATLAS, Rect2(240, 32, 64, 32), Rect2(288, 32, 64, 32))
	draw_texture_rect_region(ATLAS, Rect2(224, 144, 96, 64), RUG)
	draw_texture_rect_region(ATLAS, Rect2(64, 64, 48, 32), Rect2(288, 0, 48, 32))
	draw_texture_rect_region(ATLAS, Rect2(416, 0, 48, 48), Rect2(0, 0, 48, 48))
