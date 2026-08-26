extends Node

## tarbean_road.gd
# Post-slice epilogue beat 2: narration teaser walking out of the forest to
# Tarbean. Plays the BeatCutscene beats, then marks post_slice_flow complete
# before the cutscene's own next_scene routing lands on the end card.

const BEATS_PATH := "res://data/story/tarbean_road.json"
const POST_FLOW_PATH := "res://data/story/post_slice_flow.json"

func _ready() -> void:
	var cutscene := BeatCutscene.new()
	cutscene.beats_path = BEATS_PATH
	cutscene.auto_start = false
	add_child(cutscene)
	cutscene.sequence_finished.connect(_on_cutscene_finished)
	cutscene.start_sequence()

func _on_cutscene_finished(_id: String) -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("set_flag"):
		gs.call("set_flag", "flag_tarbean_road_seen")
	var director := SliceDirector.new()
	director.use_flow_path(POST_FLOW_PATH)
	add_child(director)
	while director.can_advance():
		director.advance_beat()
