class_name CombatTutorial
extends Node2D

## CombatTutorial
# Scripted threat tutorial (GDD §7.5): Abenthy's lesson dialogue on the four
# ways out of trouble, then a live threat encounter against the ford carter
# where every resolution is available. Completion sets flag_threat_tutorial_done
# and routes back to the campsite. Headless-friendly: phases are plain methods,
# and the scene works without autoloads (flags are applied only when present).

signal phase_changed(phase: String)

const LESSON_DIALOGUE_PATH := "res://data/dialogue/dialogue_act1_threat_lesson.json"
const THREAT_ID := "threat_ford_lout"
const RETURN_SCENE := "res://scenes/world/forest_campsite.tscn"
const DONE_FLAG := "flag_threat_tutorial_done"

var phase := ""
var _threat: ThreatEncounter = null
var _panel: ThreatPanel = null
var _runner: DialogueRunner = null
var _debrief_label: RichTextLabel = null
var _finished := false

func _ready() -> void:
	_setup_ambience()
	call_deferred("start_lesson")

## Moody wind bed under the lesson.
func _setup_ambience() -> void:
	var stream := AudioLibrary.stream_for("SFX_WIND_LIGHT")
	if stream is AudioStream:
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		var player := AudioStreamPlayer.new()
		player.name = "AmbiencePlayer"
		player.stream = stream
		player.volume_db = -14.0
		player.autoplay = true
		add_child(player)

# --- phase 1: lesson ----------------------------------------------------------

func start_lesson() -> void:
	_set_phase("lesson")
	var file := FileAccess.open(LESSON_DIALOGUE_PATH, FileAccess.READ)
	if file == null:
		push_error("CombatTutorial: cannot open %s" % LESSON_DIALOGUE_PATH)
		start_encounter()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Dictionary:
		push_error("CombatTutorial: invalid lesson dialogue")
		start_encounter()
		return

	var data := parsed as Dictionary
	var errors := DialogueRunner.validate(data)
	if errors.size() > 0:
		push_error("CombatTutorial: lesson dialogue failed validation: %s" % ", ".join(errors))
		start_encounter()
		return

	_runner = DialogueRunner.new()
	add_child(_runner)
	_runner.dialogue_finished.connect(_on_lesson_finished)
	_runner.start(data)

func _on_lesson_finished(_dialogue_id: String) -> void:
	start_encounter()

# --- phase 2: encounter -------------------------------------------------------

func start_encounter() -> void:
	_set_phase("encounter")
	var def := ThreatEncounter.find_def(THREAT_ID)
	if def.is_empty():
		push_error("CombatTutorial: threat '%s' not found" % THREAT_ID)
		finish_tutorial()
		return

	_threat = ThreatEncounter.new(def)
	_panel = ThreatPanel.new()
	add_child(_panel)
	_panel.encounter_finished.connect(_on_encounter_finished)
	_panel.open_for(_threat, _resolve_holder())

func _resolve_holder() -> Object:
	var gs := get_node_or_null("/root/GameState")
	return gs if gs != null else self

# --- phase 3: debrief ---------------------------------------------------------

func _on_encounter_finished(outcome: Dictionary) -> void:
	_set_phase("debrief")
	_show_debrief(bool(outcome.get("success", false)))

func _show_debrief(success: bool) -> void:
	if _debrief_label == null:
		_debrief_label = RichTextLabel.new()
		_debrief_label.bbcode_enabled = true
		_debrief_label.anchor_left = 0.5
		_debrief_label.anchor_top = 0.5
		_debrief_label.anchor_right = 0.5
		_debrief_label.anchor_bottom = 0.5
		_debrief_label.offset_left = -380.0
		_debrief_label.offset_right = 380.0
		_debrief_label.offset_top = -60.0
		_debrief_label.offset_bottom = 60.0
		_debrief_label.fit_content = true
		_debrief_label.scroll_active = false
		_debrief_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var layer := CanvasLayer.new()
		layer.layer = 55
		add_child(layer)
		layer.add_child(_debrief_label)
	_debrief_label.text = (
		"[center]Abenthy nods slowly. \"See? Every door opens — if you choose it early enough.\n[color=#c9b98a]Threat tutorial complete.[/color][/center]\""
		if success
		else "[center]Abenthy pulls you out of harm's way. \"Alive is a passing grade,\" he says. \"Next time, choose your door sooner.\n[color=#d98a7a]The trouble passed — poorly.[/color][/center]\""
	)

	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(finish_tutorial, CONNECT_ONE_SHOT)

## Sets the completion flag and routes back to the campsite.
func finish_tutorial() -> void:
	if _finished:
		return
	_finished = true
	_set_phase("done")

	var gs := get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("set_flag"):
		gs.call("set_flag", DONE_FLAG)

	var router := get_node_or_null("/root/SceneRouter")
	if router != null and router.has_method("change_scene"):
		router.call("change_scene", RETURN_SCENE)

func get_threat() -> ThreatEncounter:
	return _threat

func _set_phase(next: String) -> void:
	phase = next
	phase_changed.emit(phase)
