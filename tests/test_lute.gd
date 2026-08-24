extends SceneTree

# LUTE_PERFORMANCE_TEST — headless suite for the lute rhythm system.
# Proves: both charts validate; a scripted perfect playthrough grades S with
# the top reward multiplier; a sloppy pattern grades lower; practice mode
# yields zero reward; timing-window accessibility scaling widens judgments;
# density scaling thins the note count; the stage scene wires up correctly.

var _failures: int = 0

func _init() -> void:
	# Defer test execution so the SceneTree is fully ready.
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("LUTE_PERFORMANCE_TEST: START")

	_test_chart_validation()
	_test_perfect_run()
	_test_sloppy_run()
	_test_practice_mode_zero_reward()
	_test_timing_window_scaling()
	_test_density_scaling()
	_test_stage_scene()

	if _failures == 0:
		print("LUTE_PERFORMANCE_TEST: PASS")
		quit(0)
	else:
		print("LUTE_PERFORMANCE_TEST: FAIL (%d assertion(s) failed)" % _failures)
		quit(1)

func _load_chart(path: String) -> LuteChart:
	var chart := LuteChart.new()
	var ok: bool = chart.load_from_file(path)
	_assert_true(ok, "chart loads: %s" % path)
	return chart

func _test_chart_validation() -> void:
	var tutorial := _load_chart("res://data/charts/chart_tutorial_piece.json")
	var climactic := _load_chart("res://data/charts/chart_climactic_arrangement.json")

	_assert_true(tutorial.id != "", "tutorial chart has stable id")
	_assert_true(tutorial.title != "", "tutorial chart has title")
	_assert_true(tutorial.bpm > 0.0, "tutorial bpm positive")
	_assert_true(tutorial.notes.size() > 0, "tutorial chart has notes")
	_assert_eqi(tutorial.length_beats, 16.0, "tutorial length ~16 beats")

	_assert_true(climactic.id != "", "climactic chart has stable id")
	_assert_true(climactic.notes.size() > tutorial.notes.size(),
		"climactic chart denser than tutorial (%d vs %d)" % [climactic.notes.size(), tutorial.notes.size()])
	_assert_eqf(climactic.length_beats, 48.0, "climactic length ~48 beats")

	# Notes must be sorted by time and use lanes 0..3 only.
	for note in climactic.notes:
		var lane: int = int(note.get("lane", -1))
		_assert_true(lane >= 0 and lane <= 3, "climactic note lane in range")

func _test_perfect_run() -> void:
	var chart := _load_chart("res://data/charts/chart_tutorial_piece.json")
	var perf := LutePerformance.new()
	perf.set_chart(chart)

	for note in chart.notes:
		var judgment: int = perf.submit_hit(int(note["lane"]), float(note["t"]))
		_assert_eqi(judgment, LutePerformance.Judgment.PERFECT, "exact-time hit is PERFECT")

	perf.finish_performance()
	var dims: Dictionary = perf.get_dimension_scores()
	_assert_eqf(dims["timing"], 1.0, "perfect run timing dimension")
	_assert_eqf(dims["continuity"], 1.0, "perfect run continuity dimension")
	_assert_eqf(perf.get_overall_score(), 1.0, "perfect run overall score")
	_assert_true(perf.get_grade() == "S", "perfect run grades S (got %s)" % perf.get_grade())
	_assert_eqf(perf.get_reward_multiplier(false), 2.0, "S grade pays 2.0x reward")

func _test_sloppy_run() -> void:
	var chart := _load_chart("res://data/charts/chart_tutorial_piece.json")
	var perf := LutePerformance.new()
	perf.set_chart(chart)

	# Every hit lands 0.22 beats late: outside the 0.125 perfect window,
	# inside the 0.25 good window -> all GOOD judgments.
	for note in chart.notes:
		perf.submit_hit(int(note["lane"]), float(note["t"]) + 0.22)

	perf.finish_performance()
	var dims: Dictionary = perf.get_dimension_scores()
	_assert_true(float(dims["timing"]) < 1.0, "sloppy run loses timing score")
	_assert_true(perf.get_grade() != "S", "sloppy run does not grade S (got %s)" % perf.get_grade())
	_assert_true(perf.get_overall_score() < 1.0, "sloppy run scores below perfect")
	_assert_true(perf.get_reward_multiplier(false) < 2.0, "sloppy run earns reduced reward")

func _test_practice_mode_zero_reward() -> void:
	var chart := _load_chart("res://data/charts/chart_tutorial_piece.json")
	var perf := LutePerformance.new()
	perf.set_chart(chart)
	for note in chart.notes:
		perf.submit_hit(int(note["lane"]), float(note["t"]))
	perf.finish_performance()
	_assert_eqf(perf.get_reward_multiplier(true), 0.0, "practice mode forces zero reward even on S run")

func _test_timing_window_scaling() -> void:
	# Same 0.2-beat-late input judged twice: GOOD at scale 1.0,
	# PERFECT at scale 2.0 (window widens from 0.125 to 0.25).
	var chart_a := _load_chart("res://data/charts/chart_tutorial_piece.json")
	var perf_a := LutePerformance.new()
	perf_a.set_chart(chart_a)
	var first_note: Dictionary = chart_a.notes[0]
	var judgment_a: int = perf_a.submit_hit(int(first_note["lane"]), float(first_note["t"]) + 0.2)
	_assert_eqi(judgment_a, LutePerformance.Judgment.GOOD, "0.2-beat-late hit is GOOD at scale 1.0")

	var chart_b := _load_chart("res://data/charts/chart_tutorial_piece.json")
	var perf_b := LutePerformance.new()
	perf_b.set_timing_window_scale(2.0)
	perf_b.set_chart(chart_b)
	var first_note_b: Dictionary = chart_b.notes[0]
	var judgment_b: int = perf_b.submit_hit(int(first_note_b["lane"]), float(first_note_b["t"]) + 0.2)
	_assert_eqi(judgment_b, LutePerformance.Judgment.PERFECT, "same hit becomes PERFECT at scale 2.0")

func _test_density_scaling() -> void:
	var chart := _load_chart("res://data/charts/chart_climactic_arrangement.json")
	var full_count: int = chart.notes.size()
	_assert_true(full_count > 0, "climactic chart has notes before scaling")

	chart.reset_density()
	chart.apply_density_scale(0.5)
	var reduced_count: int = chart.notes.size()
	_assert_true(reduced_count < full_count,
		"density scale 0.5 thins notes (%d -> %d)" % [full_count, reduced_count])
	# keep_every = round(1 / 0.5) = 2 -> every second source note survives.
	var expected: int = int(ceil(float(full_count) / 2.0))
	_assert_eqi(reduced_count, expected, "density scale 0.5 keeps every 2nd note")

func _test_stage_scene() -> void:
	var packed: PackedScene = load("res://scenes/minigames/lute_stage.tscn") as PackedScene
	_assert_true(packed != null, "lute stage scene loads")
	if packed == null:
		return
	var stage: Node = packed.instantiate()
	_assert_true(stage != null, "lute stage instantiates")
	if stage == null:
		return
	var script: Script = stage.get_script()
	_assert_true(script != null, "lute stage has an attached script")
	_assert_true(script.get_script_property_list().any(
		func(p: Dictionary) -> bool: return p.get("name", "") == "practice_mode"),
		"stage exposes practice_mode")
	_assert_false(bool(stage.get("practice_mode")), "stage defaults to performance (non-practice) mode")
	stage.free()

func _assert_true(cond: bool, label: String) -> void:
	if cond:
		print("  ok: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)

func _assert_false(cond: bool, label: String) -> void:
	_assert_true(not cond, label)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assert_true(actual == expected, "%s (expected %s, got %s)" % [label, str(expected), str(actual)])

func _assert_eqi(actual: int, expected: int, label: String) -> void:
	_assert_true(actual == expected, "%s (expected %d, got %d)" % [label, expected, actual])

func _assert_eqf(actual: float, expected: float, label: String) -> void:
	_assert_true(absf(actual - expected) < 0.0001,
		"%s (expected %f, got %f)" % [label, expected, actual])
