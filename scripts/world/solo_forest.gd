extends WorldScene

## solo_forest.gd
# Post-slice epilogue beat 1: the ruined camp, one survivor. Reuses the
# campsite map without the troupe. The player lights a fire through sympathy
# (friction-fire working) to mark survival; that flag satisfies
# post_slice_flow beat 1 and routes onward to the Tarbean road teaser.

const POST_FLOW_PATH := "res://data/story/post_slice_flow.json"
const SURVIVAL_FLAG := "flag_post_slice_survival_done"
const NEXT_SCENE := "res://scenes/world/tarbean_road.tscn"

var _director: SliceDirector = null

func _ready() -> void:
	super()
	_director = SliceDirector.new()
	_director.use_flow_path(POST_FLOW_PATH)
	add_child(_director)

	_hook_fire_resolution()

func _hook_fire_resolution() -> void:
	var panel := get_node_or_null("SympathyPuzzlePanel") as SympathyPuzzlePanel
	if panel == null:
		push_error("solo_forest: SympathyPuzzlePanel missing — cannot resolve fire")
		return
	panel.resolved.connect(_on_fire_resolved)

func _on_fire_resolved(outcome: Dictionary) -> void:
	if not bool(outcome.get("success", false)):
		return
	var gs := get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("set_flag"):
		gs.call("set_flag", SURVIVAL_FLAG)
	if _director != null:
		while _director.can_advance():
			_director.advance_beat()
	_advance_to_tarbean()

func _advance_to_tarbean() -> void:
	var timer := get_tree().create_timer(2.2)
	timer.timeout.connect(func() -> void:
		var router := get_node_or_null("/root/SceneRouter")
		if router != null and router.has_method("change_scene"):
			router.call("change_scene", NEXT_SCENE)
	)
