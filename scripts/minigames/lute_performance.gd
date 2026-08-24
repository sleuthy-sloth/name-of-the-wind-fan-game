## LutePerformance
# Pure, deterministic scoring engine for the lute rhythm minigame.
# No engine node dependencies; driven directly by unit tests and by LuteStage.
# Grades the player on the four GDD dimensions: timing, continuity,
# expression (accuracy streaks), and recovery from mistakes.
class_name LutePerformance
extends RefCounted

enum Judgment { PERFECT, GOOD, MISS }

const PERFECT_WINDOW_BEATS: float = 0.125
const GOOD_WINDOW_BEATS: float = 0.25
const MISS_WINDOW_BEATS: float = 0.5

const WEIGHT_TIMING: float = 0.45
const WEIGHT_CONTINUITY: float = 0.25
const WEIGHT_EXPRESSION: float = 0.20
const WEIGHT_RECOVERY: float = 0.10

const RECOVERY_WINDOW_HITS: int = 4
const EXPRESSION_STREAK_MIN: int = 3

var chart: LuteChart = null
var timing_window_scale: float = 1.0
var chart_density_scale: float = 1.0

var _judgment_counts: Dictionary = {}
var _combo: int = 0
var _max_combo: int = 0
var _accuracy_streak: int = 0
var _max_accuracy_streak: int = 0
var _recovery_hits: int = 0
var _finished: bool = false

func set_chart(new_chart: LuteChart) -> void:
	chart = new_chart
	reset()
	if chart != null:
		chart.apply_density_scale(chart_density_scale)

func set_timing_window_scale(scale: float) -> void:
	timing_window_scale = maxf(scale, 0.01)

func set_chart_density_scale(scale: float) -> void:
	chart_density_scale = clampf(scale, 0.01, 4.0)
	if chart != null:
		chart.apply_density_scale(chart_density_scale)
		_clear_tracking()

func reset() -> void:
	_clear_tracking()
	if chart != null:
		chart.clear_hits()
		chart.apply_density_scale(chart_density_scale)

func _clear_tracking() -> void:
	_judgment_counts = {Judgment.PERFECT: 0, Judgment.GOOD: 0, Judgment.MISS: 0}
	_combo = 0
	_max_combo = 0
	_accuracy_streak = 0
	_max_accuracy_streak = 0
	_recovery_hits = 0
	_finished = false

## Submit a player input at the given lane and song time (in beats).
## Returns a Judgment value (PERFECT, GOOD, or MISS).
func submit_hit(lane: int, time_beats: float) -> int:
	if chart == null or chart.notes.is_empty():
		_record_judgment(Judgment.MISS)
		return Judgment.MISS

	var best_idx := _find_best_unhit_note(lane, time_beats)
	var judgment := _judge_delta(best_idx, time_beats)
	if best_idx >= 0 and judgment != Judgment.MISS:
		chart.notes[best_idx]["hit"] = true
	_record_judgment(judgment)
	return judgment

func _find_best_unhit_note(lane: int, time_beats: float) -> int:
	var best_idx := -1
	var best_dt := 999.0
	var scaled_miss := MISS_WINDOW_BEATS * timing_window_scale
	for i in range(chart.notes.size()):
		var note: Dictionary = chart.notes[i]
		if int(note.get("lane", -1)) != lane:
			continue
		if note.get("hit", false):
			continue
		var dt := absf(float(note.get("t", 0.0)) - time_beats)
		if dt < best_dt and dt <= scaled_miss:
			best_dt = dt
			best_idx = i
	return best_idx

func _judge_delta(best_idx: int, time_beats: float) -> int:
	if best_idx < 0:
		return Judgment.MISS
	var note_time: float = float(chart.notes[best_idx].get("t", 0.0))
	var dt := absf(note_time - time_beats)
	var scaled_perfect := PERFECT_WINDOW_BEATS * timing_window_scale
	var scaled_good := GOOD_WINDOW_BEATS * timing_window_scale
	var scaled_miss := MISS_WINDOW_BEATS * timing_window_scale
	if dt <= scaled_perfect:
		return Judgment.PERFECT
	elif dt <= scaled_good:
		return Judgment.GOOD
	elif dt <= scaled_miss:
		return Judgment.MISS
	return Judgment.MISS

func _record_judgment(judgment: int) -> void:
	_judgment_counts[judgment] = _judgment_counts.get(judgment, 0) + 1
	if judgment == Judgment.MISS:
		_combo = 0
		_accuracy_streak = 0
	else:
		_combo += 1
		if _combo > _max_combo:
			_max_combo = _combo
		_accuracy_streak += 1
		if _accuracy_streak > _max_accuracy_streak:
			_max_accuracy_streak = _accuracy_streak
		if _judgment_counts.get(Judgment.MISS, 0) > 0:
			_recovery_hits += 1

## Call when the performance ends to count any unhit notes as misses.
func finish_performance() -> void:
	if _finished:
		return
	_finished = true
	if chart == null:
		return
	var unhit := 0
	for note in chart.notes:
		if not note.get("hit", false):
			unhit += 1
	_judgment_counts[Judgment.MISS] = _judgment_counts.get(Judgment.MISS, 0) + unhit

## Returns {timing, continuity, expression, recovery} each in [0, 1].
func get_dimension_scores() -> Dictionary:
	var perfect := float(_judgment_counts.get(Judgment.PERFECT, 0))
	var good := float(_judgment_counts.get(Judgment.GOOD, 0))
	var miss := float(_judgment_counts.get(Judgment.MISS, 0))
	var total := perfect + good + miss
	if total <= 0.0:
		return {"timing": 0.0, "continuity": 0.0, "expression": 0.0, "recovery": 0.0}

	var timing := (perfect * 1.0 + good * 0.6) / total
	var continuity := clampf(float(_max_combo) / total, 0.0, 1.0)
	var expression := 0.0
	if _max_accuracy_streak >= EXPRESSION_STREAK_MIN:
		expression = clampf(float(_max_accuracy_streak) / total, 0.0, 1.0)
	var recovery := 1.0
	var miss_count := int(miss)
	if miss_count > 0:
		var potential := float(miss_count * RECOVERY_WINDOW_HITS)
		recovery = clampf(float(_recovery_hits) / potential, 0.0, 1.0)

	return {
		"timing": timing,
		"continuity": continuity,
		"expression": expression,
		"recovery": recovery,
	}

func get_overall_score() -> float:
	var dims := get_dimension_scores()
	return (
		dims["timing"] * WEIGHT_TIMING
		+ dims["continuity"] * WEIGHT_CONTINUITY
		+ dims["expression"] * WEIGHT_EXPRESSION
		+ dims["recovery"] * WEIGHT_RECOVERY
	)

func get_grade() -> String:
	var score := get_overall_score()
	if score >= 0.95:
		return "S"
	elif score >= 0.85:
		return "A"
	elif score >= 0.70:
		return "B"
	elif score >= 0.55:
		return "C"
	return "D"

## Returns the economic reward multiplier for the current grade.
## Practice mode always returns 0 regardless of grade.
func get_reward_multiplier(practice_mode: bool = false) -> float:
	if practice_mode:
		return 0.0
	match get_grade():
		"S": return 2.0
		"A": return 1.5
		"B": return 1.0
		"C": return 0.5
		_: return 0.0

func get_judgment_counts() -> Dictionary:
	return _judgment_counts.duplicate()

func is_finished() -> bool:
	return _finished
