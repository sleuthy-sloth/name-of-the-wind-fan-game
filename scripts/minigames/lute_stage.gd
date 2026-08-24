## LuteStage
# Playable Node2D stage for the lute rhythm minigame.
# Renders approaching note markers (ColorRect placeholders), accepts keyboard
# A/S/D/F and controller face-button input mapped in code, provides audible
# tick feedback via AudioStreamGenerator, and shows timing popups plus a final
# grade breakdown. Practice mode forces reward_multiplier to 0.
class_name LuteStage
extends Node2D

@export var chart_path: String = "res://data/charts/chart_tutorial_piece.json"
@export var practice_mode: bool = false
@export var scroll_speed_beats_per_sec: float = 2.0
@export var note_fall_distance: float = 400.0

const LANE_COUNT: int = 4
const LANE_KEYCODES: Array[int] = [KEY_A, KEY_S, KEY_D, KEY_F]
const LANE_JOY_BUTTONS: Array[int] = [JOY_BUTTON_X, JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_Y]

var chart: LuteChart = null
var performance: LutePerformance = null

var _audio_player: AudioStreamPlayer = null
var _generator_playback: AudioStreamGeneratorPlayback = null
var _lute_sample_player: AudioStreamPlayer = null
var _lute_samples: Dictionary = {}
var _note_markers: Array[ColorRect] = []
var _feedback_label: Label = null
var _feedback_timer: float = 0.0
var _result_panel: PanelContainer = null
var _result_label: Label = null
var _running: bool = false
var _current_time_beats: float = 0.0

func _ready() -> void:
	_build_ui()
	_setup_audio()
	load_chart(chart_path)

func load_chart(path: String) -> bool:
	chart = LuteChart.new()
	if not chart.load_from_file(path):
		chart = null
		performance = null
		push_error("LuteStage: failed to load chart %s" % path)
		return false
	performance = LutePerformance.new()
	performance.set_chart(chart)
	_spawn_note_markers()
	return true

func start_performance() -> void:
	if chart == null or performance == null:
		return
	_running = true
	_current_time_beats = 0.0
	performance.reset()
	_result_panel.visible = false
	if _audio_player != null and not _audio_player.playing:
		_audio_player.play()
	_generator_playback = _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _build_ui() -> void:
	# PLACEHOLDER: lane target line
	var hit_line := ColorRect.new()
	hit_line.name = "HitLine"
	hit_line.custom_minimum_size = Vector2(320, 4)
	hit_line.color = Color.WHITE
	hit_line.position = Vector2(-160, 100)
	add_child(hit_line)

	# PLACEHOLDER: lane receptor markers
	var lanes := Node2D.new()
	lanes.name = "Lanes"
	add_child(lanes)
	for lane in range(LANE_COUNT):
		var lane_marker := ColorRect.new()
		lane_marker.name = "Lane%d" % lane
		lane_marker.custom_minimum_size = Vector2(48, 48)
		lane_marker.color = Color(0.2, 0.2 + lane * 0.15, 0.4, 1.0)
		lane_marker.position = Vector2(-160 + lane * 80, 76)
		lanes.add_child(lane_marker)

	# PLACEHOLDER: approaching note container
	var notes_container := Node2D.new()
	notes_container.name = "NoteMarkers"
	add_child(notes_container)

	# Timing feedback popup
	_feedback_label = Label.new()
	_feedback_label.name = "FeedbackLabel"
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback_label.position = Vector2(-100, -80)
	_feedback_label.custom_minimum_size = Vector2(200, 40)
	_feedback_label.add_theme_font_size_override("font_size", 24)
	_feedback_label.modulate = Color.TRANSPARENT
	add_child(_feedback_label)

	# Result panel
	_result_panel = PanelContainer.new()
	_result_panel.name = "ResultPanel"
	_result_panel.position = Vector2(-200, -150)
	_result_panel.custom_minimum_size = Vector2(400, 300)
	_result_panel.visible = false
	add_child(_result_panel)

	_result_label = Label.new()
	_result_label.name = "ResultLabel"
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.custom_minimum_size = Vector2(380, 280)
	_result_panel.add_child(_result_label)

func _setup_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "AudioStreamPlayer"
	add_child(_audio_player)
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = 0.1
	_audio_player.stream = generator
	_lute_sample_player = AudioStreamPlayer.new()
	_lute_sample_player.name = "LuteSamplePlayer"
	add_child(_lute_sample_player)
	var lane_notes: Array[String] = ["D3", "G3", "A3", "B3"]
	for note_name in lane_notes:
		var path := "res://audio/sfx/lute_%s.ogg" % note_name
		var stream := load(path)
		if stream is AudioStream:
			_lute_samples[note_name] = stream

func _spawn_note_markers() -> void:
	var container := get_node_or_null("NoteMarkers")
	if container == null:
		return
	for marker in _note_markers:
		marker.queue_free()
	_note_markers.clear()
	if chart == null:
		return
	for note in chart.notes:
		var marker := ColorRect.new()
		marker.custom_minimum_size = Vector2(32, 32)
		marker.color = Color.YELLOW
		container.add_child(marker)
		_note_markers.append(marker)

func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	var lane := _resolve_lane(event)
	if lane < 0:
		return
	var judgment := performance.submit_hit(lane, _current_time_beats)
	_show_feedback(judgment)
	_play_tick(lane)

func _resolve_lane(event: InputEvent) -> int:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		for i in range(LANE_COUNT):
			if key_event.keycode == LANE_KEYCODES[i]:
				return i
	elif event is InputEventJoypadButton and event.pressed:
		var joy_event := event as InputEventJoypadButton
		for i in range(LANE_COUNT):
			if joy_event.button_index == LANE_JOY_BUTTONS[i]:
				return i
	return -1

func _show_feedback(judgment: int) -> void:
	var text := ""
	var color := Color.WHITE
	match judgment:
		LutePerformance.Judgment.PERFECT:
			text = "PERFECT"
			color = Color.CYAN
		LutePerformance.Judgment.GOOD:
			text = "GOOD"
			color = Color.GREEN
		LutePerformance.Judgment.MISS:
			text = "MISS"
			color = Color.RED
	_feedback_label.text = text
	_feedback_label.modulate = color
	_feedback_timer = 0.4

func _try_lute_sample(lane: int) -> bool:
	if _lute_sample_player == null:
		return false
	var lane_notes: Array[String] = ["D3", "G3", "A3", "B3"]
	if lane < 0 or lane >= lane_notes.size():
		return false
	var note_name: String = lane_notes[lane]
	if not _lute_samples.has(note_name):
		return false
	_lute_sample_player.stream = _lute_samples[note_name]
	_lute_sample_player.play()
	return true

func _play_tick(lane: int = -1) -> void:
	if _try_lute_sample(lane):
		return
	if _generator_playback == null:
		return
	var mix_rate := float(_generator_playback.get_mix_rate())
	var duration := 0.05
	var frames := int(mix_rate * duration)
	var phase := 0.0
	var increment := 880.0 / mix_rate * TAU
	for i in range(frames):
		var envelope := 1.0 - float(i) / float(frames)
		var sample := sin(phase) * 0.2 * envelope
		_generator_playback.push_frame(Vector2(sample, sample))
		phase += increment

func _process(delta: float) -> void:
	if _feedback_timer > 0.0:
		_feedback_timer -= delta
		if _feedback_timer <= 0.0:
			_feedback_label.modulate = Color.TRANSPARENT

	if not _running:
		return

	_current_time_beats += delta * scroll_speed_beats_per_sec
	_update_note_positions()

	if chart != null and _current_time_beats >= chart.length_beats + 2.0:
		_end_performance()

func _update_note_positions() -> void:
	if chart == null:
		return
	var pixels_per_beat := note_fall_distance / 4.0
	for i in range(_note_markers.size()):
		var marker := _note_markers[i]
		var note: Dictionary = chart.notes[i]
		if note.get("hit", false):
			marker.visible = false
			continue
		var note_time: float = float(note.get("t", 0.0))
		var lane: int = int(note.get("lane", 0))
		var distance := (note_time - _current_time_beats) * pixels_per_beat
		marker.visible = distance >= 0.0 and distance <= note_fall_distance
		marker.position = Vector2(-160 + lane * 80 + 8, 92 - distance)

func _end_performance() -> void:
	_running = false
	performance.finish_performance()
	_show_result()

func _show_result() -> void:
	var grade := performance.get_grade()
	var score := performance.get_overall_score()
	var multiplier := performance.get_reward_multiplier(practice_mode)
	var dims := performance.get_dimension_scores()
	var text := "Grade: %s\nScore: %.2f\n" % [grade, score]
	text += "Timing: %.2f | Continuity: %.2f\n" % [dims["timing"], dims["continuity"]]
	text += "Expression: %.2f | Recovery: %.2f\n" % [dims["expression"], dims["recovery"]]
	if practice_mode:
		text += "\nPractice mode — no economic consequences.\nReward multiplier: 0.0"
	else:
		text += "\nReward multiplier: %.1fx" % multiplier
	_result_label.text = text
	_result_panel.visible = true

func get_stage_result() -> Dictionary:
	if performance == null:
		return {}
	return {
		"grade": performance.get_grade(),
		"score": performance.get_overall_score(),
		"multiplier": performance.get_reward_multiplier(practice_mode),
		"practice_mode": practice_mode,
		"dimensions": performance.get_dimension_scores(),
	}

func is_running() -> bool:
	return _running
