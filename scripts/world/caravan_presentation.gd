class_name CaravanPresentation
extends Node2D

## Source-backed, visual-only caravan dressing. Imported CC0 textures provide
## geometry; this script only animates atmosphere.

const WAGON_ART_PATH := "res://art/generated/opening_art/caravan_wagon_a.png"

var _animation_enabled := true
var _elapsed := 0.0


func _ready() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		_animation_enabled = not bool(settings.get("reduce_motion"))

func set_reduced_motion(enabled: bool) -> void:
	_animation_enabled = not enabled

func _process(delta: float) -> void:
	if _animation_enabled:
		_elapsed += delta
		var atmosphere := get_node_or_null("Atmosphere")
		if atmosphere != null:
			atmosphere.modulate.a = 0.92 + sin(_elapsed * 1.8) * 0.08
