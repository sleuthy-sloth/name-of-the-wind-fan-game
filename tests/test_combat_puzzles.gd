extends SceneTree

## test_combat_puzzles.gd
## Headless verification of the threat/combat + sympathy puzzle layer:
## GDD §7.5 ThreatEncounter (flee/hide/talk/sympathy, pressure, flags),
## out-of-combat SympathyPuzzle workings (source choice drives cost/risk,
## commit applies world effects), SympathyTarget node application,
## BeatCutscene playback (Waystone Inn opening), and tutorial content
## validation. Prints COMBAT_PUZZLE_TEST: PASS/FAIL.

var _failures := 0
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _run() -> void:
	await physics_frame
	await physics_frame
	await _test_workings_data()
	await _test_sympathy_puzzle()
	await _test_sympathy_target_node()
	await _test_threats_data()
	await _test_threat_talk()
	await _test_threat_flee()
	await _test_threat_hide()
	await _test_threat_sympathy()
	await _test_threat_pressure()
	await _test_waystone_opening_data()
	await _test_beat_cutscene_playback()
	await _test_tutorial_content()
	await _test_scene_wiring()

	if _failures == 0:
		print("COMBAT_PUZZLE_TEST: PASS (%d/%d checks)" % [_checks, _checks])
	else:
		print("COMBAT_PUZZLE_TEST: FAIL (%d/%d checks passed)" % [_checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)


class MockHolder extends RefCounted:
	var alar := 100.0
	var max_alar := 100.0
	var relationships := {}
	var reputation := {}


## Finds a seed whose FIRST randf() lands at/above (want_high) or below the
## threshold, so rolls through SympathyEngine are deterministic in tests.
func _seeded_rng(first_roll: float, want_at_or_above: bool) -> RandomNumberGenerator:
	for seed_value in range(1, 200000):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var roll := rng.randf()
		var hit := roll >= first_roll if want_at_or_above else roll < first_roll
		if hit:
			rng.seed = seed_value
			return rng
	return RandomNumberGenerator.new()


# --- workings data ---------------------------------------------------------------

func _test_workings_data() -> void:
	var defs := SympathyPuzzle.load_defs()
	_check(defs.size() == 2, "workings_act1 has 2 defs")
	var ids := {}
	for d in defs:
		for error in SympathyPuzzle.validate_def(d):
			_check(false, "working '%s': %s" % [str(d.get("id", "?")), error])
		ids[str(d.get("id", ""))] = true
	_check(ids.has("working_jammed_wagon_gate"), "wagon gate working present")
	_check(ids.has("working_swollen_hatch_latch"), "hatch working present")


# --- sympathy puzzle model -------------------------------------------------------

const WORKING_WAGON := "working_jammed_wagon_gate"

func _make_puzzle(working_id: String) -> SympathyPuzzle:
	return SympathyPuzzle.new(SympathyPuzzle.find_def(working_id), _seeded_rng(0.9, true))


func _test_sympathy_puzzle() -> void:
	var puzzle := _make_puzzle(WORKING_WAGON)
	_check(not puzzle.def.is_empty(), "wagon def found")
	_check(puzzle.sources().size() == 2, "wagon offers two sources")

	puzzle.select_source(0)
	var strong := puzzle.preview()
	_check(bool(strong.get("valid", false)), "strong source binding valid")
	_check(float(strong.get("risk", 1.0)) < 0.05, "strong source risk near zero")

	puzzle.select_source(1)
	var weak := puzzle.preview()
	_check(float(weak.get("risk", 0.0)) > 0.15, "weak source raises risk")
	_check(float(weak.get("cost", 0.0)) >= float(strong.get("cost", 999.0)), "weak source costs at least as much")

	var holder := MockHolder.new()
	puzzle.select_source(0)
	var committed := puzzle.commit(holder)
	_check(bool(committed.get("success", false)), "strong-source commit succeeds")
	_check(str(committed.get("world_effect", "")) == "move_obstacle", "commit carries world effect")
	_check(str(committed.get("flag", "")) == "flag_camp_wagon_gate_moved", "commit carries success flag")
	_check(float(committed.get("alar_spent", 0.0)) > 0.0, "commit spends Alar")
	_check(holder.alar < holder.max_alar, "holder Alar reduced")

	var failing := _make_puzzle(WORKING_WAGON)
	failing.engine.set_rng(_seeded_rng(0.1, false))
	failing.select_source(1)
	var fail_holder := MockHolder.new()
	fail_holder.alar = 3.0
	var failed_result := failing.commit(fail_holder)
	_check(not bool(failed_result.get("success", true)), "weak+unlucky commit fails")
	_check(not failed_result.has("flag"), "failed commit sets no flag")
	_check(not str(failed_result.get("failure_consequence", "")).is_empty(), "failed commit reports consequence")


# --- sympathy target node --------------------------------------------------------

func _test_sympathy_target_node() -> void:
	var parent := Node2D.new()
	root.add_child(parent)

	var obstacle := StaticBody2D.new()
	obstacle.name = "Obstacle"
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 20)
	shape_node.shape = shape
	obstacle.add_child(shape_node)
	parent.add_child(obstacle)

	var target_script := load("res://scripts/world/sympathy_target.gd") as GDScript
	_check(target_script != null, "sympathy_target.gd loads")
	if target_script == null:
		parent.queue_free()
		return
	var target := Area2D.new()
	target.set_script(target_script)
	parent.add_child(target)
	target.set("working_id", WORKING_WAGON)
	target.set("obstacle_path", NodePath("../Obstacle"))
	target.set("move_offset", Vector2(-40, 0))

	var requested := [false]
	target.connect(
		"puzzle_requested",
		func(_t) -> void: requested[0] = true
	)
	target.call("interact")
	_check(requested[0], "interact emits puzzle_requested")
	_check(not bool(target.get("is_resolved")), "target not resolved before success")

	var result := {
		"success": true,
		"world_effect": "move_obstacle",
		"flag": "flag_test_moved",
	}
	var start_position: Vector2 = obstacle.position
	target.call("apply_success", result)
	_check(bool(target.get("is_resolved")), "apply_success resolves target")
	for i in range(70):
		await physics_frame
	var moved: Vector2 = obstacle.position - start_position
	_check(moved.x <= -30.0, "move_obstacle tween displaced obstacle (dx=%.1f)" % moved.x)

	# open_door path disables the barrier collision.
	result["world_effect"] = "open_door"
	var target2 := Area2D.new()
	target2.set_script(target_script)
	parent.add_child(target2)
	target2.set("obstacle_path", NodePath("../Obstacle"))
	target2.call("apply_success", result)
	_check(shape_node.disabled, "open_door disables barrier collision")

	parent.queue_free()


# --- threats data ----------------------------------------------------------------

func _test_threats_data() -> void:
	var defs := ThreatEncounter.load_defs()
	_check(defs.size() == 2, "threats_act1 has 2 defs")
	var ford_found := false
	for d in defs:
		for error in ThreatEncounter.validate_def(d):
			_check(false, "threat '%s': %s" % [str(d.get("id", "?")), error])
		if str(d.get("id", "")) == "threat_ford_lout":
			ford_found = true
	_check(ford_found, "ford lout threat present")

	var ford := ThreatEncounter.new(ThreatEncounter.find_def("threat_ford_lout"))
	_check(ford.flee_routes().size() == 2, "ford offers two flee routes")
	_check(ford.hide_window().y > 0.0, "ford hide window positive")
	_check(str(ford.talk_requirement().get("kind", "")) == "relationship", "ford talk gated by relationship")
	_check(not ford.sympathy_binding().is_empty(), "ford offers sympathy resolution")


func _mock_holder(relationship_abenthy: float) -> MockHolder:
	var holder := MockHolder.new()
	holder.relationships = {"char_abenthy": relationship_abenthy}
	holder.reputation = {}
	return holder


# --- threat resolutions ----------------------------------------------------------

func _test_threat_talk() -> void:
	var threat := ThreatEncounter.new(ThreatEncounter.find_def("threat_ford_lout"))

	var low := threat.attempt("talk", {}, _mock_holder(-1.0))
	_check(not bool(low.get("success", true)), "talk fails without standing")
	_check(int(low.get("pressure", 0)) == 1, "failed talk raises pressure")
	_check(threat.is_active(), "threat still active after one failure")

	var high := threat.attempt("talk", {}, _mock_holder(2.0))
	_check(bool(high.get("success", false)), "talk succeeds with Abenthy's trust")
	_check(bool(high.get("resolved", false)), "successful talk resolves encounter")
	var flags := threat.flags_for(high)
	_check(flags.has("flag_threat_ford_lout_resolved"), "success flag mapped")


func _test_threat_flee() -> void:
	var always_safe := {"id": "t", "title": "t", "pressure_limit": 3,
		"flee": {"routes": [
			{"id": "safe", "risk": 0.0},
			{"id": "doomed", "risk": 1.0},
		]},
		"flags": {}}
	var threat := ThreatEncounter.new(always_safe)
	var safe := threat.attempt("flee", {"route_index": 0}, _mock_holder(0.0))
	_check(bool(safe.get("success", false)), "zero-risk route always escapes")
	_check(str(safe.get("route_id", "")) == "safe", "route id echoed in outcome")

	var threat2 := ThreatEncounter.new(always_safe.duplicate(true))
	var doomed := threat2.attempt("flee", {"route_index": 1}, _mock_holder(0.0))
	_check(not bool(doomed.get("success", true)), "certain route fails")
	_check(threat2.pressure == 1, "failed flee escalates pressure")

	var bad := ThreatEncounter.new({"id": "x", "title": "x", "pressure_limit": 2})
	var missing := bad.attempt("flee", {}, _mock_holder(0.0))
	_check(not bool(missing.get("success", true)), "missing route rejected")


func _test_threat_hide() -> void:
	var threat := ThreatEncounter.new(ThreatEncounter.find_def("threat_ford_lout"))
	_check(not threat.is_resolved(), "fresh threat unresolved")
	var good := threat.attempt("hide", {"timing": 0.5}, _mock_holder(0.0))
	_check(bool(good.get("success", false)), "timing inside window hides")
	var threat2 := ThreatEncounter.new(ThreatEncounter.find_def("threat_ford_lout"))
	var early := threat2.attempt("hide", {"timing": 0.02}, _mock_holder(0.0))
	_check(not bool(early.get("success", true)), "timing outside window spotted")


func _test_threat_sympathy() -> void:
	var threat := ThreatEncounter.new(ThreatEncounter.find_def("threat_ford_lout"))
	var preview := threat.sympathy_preview()
	_check(float(preview.get("cost", 0.0)) > 0.0, "sympathy preview shows cost")

	var holder := _mock_holder(0.0)
	holder.alar = 100.0
	holder.max_alar = 100.0
	var outcome := threat.attempt("sympathy", {}, holder)
	_check(bool(outcome.get("success", false)), "in-combat sympathy working succeeds")
	_check(bool(outcome.get("resolved", false)), "sympathy resolves the threat")
	_check(float(outcome.get("alar_spent", 0.0)) > 0.0, "sympathy spends Alar under pressure")
	_check(holder.alar < 100.0, "holder Alar drained by working")

	# Weak custom binding mostly fails and escalates pressure.
	var weak_def := {
		"id": "weak", "title": "w", "pressure_limit": 4,
		"sympathy": {
			"source": {"id": "s", "domain": "thermal", "energy": 1.0},
			"link": {"id": "l", "domains": ["thermal"], "quality": 0.5},
			"target": {"id": "t", "domain": "thermal", "tolerance": 0.1},
			"effect": {"id": "e", "domain": "thermal", "cost": 3.0},
		},
		"flags": {},
	}
	var weak := ThreatEncounter.new(weak_def)
	var slip := weak.attempt("sympathy", {}, _mock_holder(0.0))
	_check(not bool(slip.get("success", true)), "weak binding slips under pressure")
	_check(weak.pressure == 1, "slippage escalates pressure")


func _test_threat_pressure() -> void:
	var tight_def := {
		"id": "tight", "title": "t", "pressure_limit": 2,
		"hide": {"window_center": 0.5, "window_width": 0.001},
		"flags": {"failure_flag": "flag_test_forced_fail"},
	}
	var threat := ThreatEncounter.new(tight_def)
	threat.attempt("hide", {"timing": 0.0}, _mock_holder(0.0))
	var last := threat.attempt("hide", {"timing": 1.0}, _mock_holder(0.0))
	_check(bool(last.get("resolved", false)), "pressure limit resolves encounter")
	_check(bool(last.get("forced_failure", false)), "limit exhaustion is forced failure")
	_check(not threat.is_active(), "exhausted threat inactive")
	var flags := threat.flags_for(last)
	_check(flags.has("flag_test_forced_fail"), "failure flag mapped")


# --- waystone opening ------------------------------------------------------------

const KNOWN_EFFECTS := ["calm", "unease", "dim", "warm", "darkness"]

func _test_waystone_opening_data() -> void:
	var file := FileAccess.open("res://data/story/waystone_opening.json", FileAccess.READ)
	_check(file != null, "waystone_opening.json opens")
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(parsed is Dictionary, "waystone opening parses to dict")
	if not parsed is Dictionary:
		return
	var data := parsed as Dictionary
	_check(str(data.get("id", "")) == "waystone_opening", "opening id set")
	var beats: Variant = data.get("beats")
	_check(beats is Array and (beats as Array).size() >= 4, "opening has enough beats")
	if not beats is Array:
		return
	for i in range((beats as Array).size()):
		var beat := (beats as Array)[i] as Dictionary
		_check(not str(beat.get("narration", "")).is_empty(), "beat %d has narration" % i)
		_check(float(beat.get("duration", 0.0)) > 0.0, "beat %d has duration" % i)
		_check(KNOWN_EFFECTS.has(str(beat.get("effect", "calm"))), "beat %d uses known effect" % i)
	var last := (beats as Array)[(beats as Array).size() - 1] as Dictionary
	_check(str(last.get("set_flag", "")) == "waystone_opening_seen", "final beat sets opening flag")
	_check(str(last.get("next_scene", "")) == "res://scenes/world/caravan_route.tscn", "final beat routes to caravan")
	var sfx_ok := true
	for beat_v: Variant in beats as Array:
		var sfx := str((beat_v as Dictionary).get("sfx", ""))
		if not sfx.is_empty() and not AudioLibrary.has_event(sfx):
			sfx_ok = false
	_check(sfx_ok, "all beat sfx events exist in manifest")


func _test_beat_cutscene_playback() -> void:
	var test_beats := {
		"id": "test_cut",
		"beats": [
			{"narration": "One.", "effect": "warm", "duration": 0.05, "set_flag": "flag_test_cut_one"},
			{"narration": "Two.", "effect": "dim", "duration": 0.05},
		],
	}
	var path := "user://test_beat_cutscene.json"
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_string(JSON.stringify(test_beats))
	writer.close()

	var cutscene := BeatCutscene.new()
	cutscene.auto_start = false
	cutscene.beats_path = path
	root.add_child(cutscene)

	var finished_ids := []
	cutscene.sequence_finished.connect(func(id: String) -> void: finished_ids.append(id))
	cutscene.start_sequence()

	var frames := 0
	while not cutscene.is_sequence_complete() and frames < 600:
		await physics_frame
		frames += 1
	_check(cutscene.is_sequence_complete(), "beat cutscene completes")
	_check(finished_ids.size() == 1 and finished_ids[0] == "test_cut", "sequence_finished emitted once with id")

	cutscene.queue_free()


# --- tutorial content ------------------------------------------------------------

func _test_tutorial_content() -> void:
	var file := FileAccess.open("res://data/dialogue/dialogue_act1_threat_lesson.json", FileAccess.READ)
	_check(file != null, "threat lesson dialogue opens")
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(parsed is Dictionary, "threat lesson parses")
	if not parsed is Dictionary:
		return
	var errors := DialogueRunner.validate(parsed as Dictionary)
	_check(errors.is_empty(), "threat lesson dialogue validates clean (%s)" % ", ".join(errors))


# --- scene wiring ----------------------------------------------------------------

func _test_scene_wiring() -> void:
	var campsite_text := FileAccess.get_file_as_string("res://scenes/world/forest_campsite.tscn")
	_check(campsite_text.contains("working_jammed_wagon_gate"), "campsite wires wagon gate target")
	_check(campsite_text.contains("working_swollen_hatch_latch"), "campsite wires hatch target")
	_check(campsite_text.contains("combat_tutorial.tscn"), "campsite door leads to combat tutorial")
	_check(ResourceLoader.exists("res://scenes/world/combat_tutorial.tscn"), "combat tutorial scene exists")
	_check(ResourceLoader.exists("res://scripts/ui/threat_panel.gd"), "ThreatPanel script exists")
	_check(ResourceLoader.exists("res://scripts/ui/sympathy_puzzle_panel.gd"), "SympathyPuzzlePanel script exists")
	_check(load("res://scenes/world/combat_tutorial.tscn") != null, "combat tutorial scene loads")

	var project_text := FileAccess.get_file_as_string("res://project.godot")
	_check(project_text.contains("waystone_inn.tscn"), "main scene points at Waystone Inn opening")
