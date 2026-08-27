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
	await _test_road_threat_subset()
	await _test_threat_trigger_node()
	await _test_waystone_opening_data()
	await _test_beat_cutscene_playback()
	await _test_tutorial_content()
	await _test_light_fire_effect()
	await _test_post_slice_flow()
	await _test_inn_interior_and_tarbean_data()
	await _test_title_menu_and_skip()
	await _test_settings_and_credits()
	await _test_chronicler_and_map()
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
	_check(defs.size() == 5, "workings_act1 has 5 defs")
	var ids := {}
	for d in defs:
		for error in SympathyPuzzle.validate_def(d):
			_check(false, "working '%s': %s" % [str(d.get("id", "?")), error])
		ids[str(d.get("id", ""))] = true
	_check(ids.has("working_jammed_wagon_gate"), "wagon gate working present")
	_check(ids.has("working_swollen_hatch_latch"), "hatch working present")
	_check(ids.has("working_split_boulder"), "boulder working present")
	_check(ids.has("working_light_the_lamp"), "inn lamp working present")
	_check(ids.has("working_friction_fire"), "friction fire working present")


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
	_check(defs.size() == 3, "threats_act1 has 3 defs")
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


# --- subset threats + trigger node ------------------------------------------------

func _test_road_threat_subset() -> void:
	var dogs := ThreatEncounter.new(ThreatEncounter.find_def("threat_road_dogs"))
	_check(dogs.flee_routes().size() == 2, "road dogs offer two flee routes")
	_check(dogs.def.has("hide"), "road dogs offer hide")
	_check(not dogs.def.has("talk"), "road dogs cannot be talked to")
	_check(not dogs.def.has("sympathy"), "road dogs offer no sympathy resolution")

	var outcome := dogs.attempt("talk", {}, _mock_holder(9.0))
	_check(not bool(outcome.get("success", true)), "talk on talk-less threat rejected")
	_check(int(outcome.get("pressure", 0)) == 0, "invalid attempt does not escalate pressure")

	var hide := dogs.attempt("hide", {"timing": 0.55}, _mock_holder(0.0))
	_check(bool(hide.get("success", false)), "road dog hide window works")

	var boulder := _make_puzzle("working_split_boulder")
	boulder.select_source(0)
	var strong := boulder.preview()
	_check(bool(strong.get("valid", false)), "boulder torch binding valid")
	_check(float(strong.get("risk", 1.0)) < 0.05, "torch source splits stone near-certainly")
	var holder := MockHolder.new()
	var committed := boulder.commit(holder)
	_check(bool(committed.get("success", false)), "boulder commit succeeds with torch")
	_check(str(committed.get("world_effect", "")) == "move_obstacle", "boulder effect moves obstacle")
	_check(str(committed.get("flag", "")) == "flag_road_boulder_cleared", "boulder flag mapped")


func _test_threat_trigger_node() -> void:
	var script := load("res://scripts/world/threat_trigger.gd") as GDScript
	_check(script != null, "threat_trigger.gd loads")
	if script == null:
		return
	var trigger_holder := Node2D.new()
	root.add_child(trigger_holder)
	var trigger := Area2D.new()
	trigger.set_script(script)
	trigger_holder.add_child(trigger)
	trigger.set("threat_id", "threat_road_dogs")

	var requested := [false]
	trigger.connect(
		"threat_requested",
		func(_t) -> void: requested[0] = true
	)
	trigger.call("interact")
	_check(requested[0], "trigger interact emits threat_requested")

	var built := trigger.call("build_threat") as ThreatEncounter
	_check(built != null and not built.def.is_empty(), "build_threat finds def by id")
	if built != null:
		_check(str(built.get_title()) == "Half-Starved Dogs on the Road", "built threat is road dogs")

	# Successful resolution retires the trigger.
	trigger.call("resolve_after_encounter", built, {"resolved": true, "success": true})
	_check(trigger.is_queued_for_deletion(), "successful encounter retires trigger")

	# Failed resolution keeps a fresh trigger available for retry.
	var retry := Area2D.new()
	retry.set_script(script)
	trigger_holder.add_child(retry)
	retry.set("threat_id", "threat_road_dogs")
	retry.call("resolve_after_encounter", built, {"resolved": true, "success": false})
	_check(not retry.is_queued_for_deletion(), "failed encounter leaves trigger for retry")

	trigger_holder.queue_free()


# --- light_fire world effect -----------------------------------------------------

func _test_light_fire_effect() -> void:
	var holder_node := Node2D.new()
	root.add_child(holder_node)

	var flame_parent := Node2D.new()
	flame_parent.name = "LampFlame"
	flame_parent.visible = false
	holder_node.add_child(flame_parent)
	var flame := ColorRect.new()
	flame.name = "Flame"
	flame.visible = false
	flame_parent.add_child(flame)

	var target_script := load("res://scripts/world/sympathy_target.gd") as GDScript
	_check(target_script != null, "sympathy_target.gd loads for light_fire")
	if target_script == null:
		holder_node.queue_free()
		return
	var target := Area2D.new()
	target.set_script(target_script)
	holder_node.add_child(target)
	target.set("working_id", "working_light_the_lamp")
	target.set("obstacle_path", NodePath("../LampFlame"))

	var result := {
		"success": true,
		"world_effect": "light_fire",
		"flag": "flag_inn_lamp_lit",
	}
	target.call("apply_success", result)
	_check(bool(target.get("is_resolved")), "light_fire resolves target")
	_check(flame_parent.visible, "light_fire reveals the flame node")

	holder_node.queue_free()


# --- post-slice flow -------------------------------------------------------------

const POST_FLOW_PATH := "res://data/story/post_slice_flow.json"

func _test_post_slice_flow() -> void:
	# Provide a GameState node so SliceDirector can track quest state.
	if root.get_node_or_null("GameState") == null:
		var gs: Node = load("res://scripts/systems/game_state.gd").new()
		gs.name = "GameState"
		root.add_child(gs)
	var gs := root.get_node_or_null("GameState")

	var director := SliceDirector.new()
	director.use_flow_path(POST_FLOW_PATH)
	root.add_child(director)
	await process_frame

	_check(director.get_current_beat().get("id", "") == "beat_solo_survive",
		"post-slice flow starts at solo survive beat")
	_check(str(director.get_current_beat().get("scene", "")) == "res://scenes/world/solo_forest.tscn",
		"solo beat points at solo_forest scene")
	_check(director.can_advance(), "post-slice first beat needs no flags")
	_check(director.advance_beat(), "post-slice advances into tarbean beat")
	_check(director.get_current_beat().get("id", "") == "beat_tarbean_road",
		"second beat is tarbean road")
	_check(gs.has_flag("flag_post_slice_survival_done"),
		"advancing past solo beat sets its completion flag")

	_check(director.can_advance(), "survival flag satisfies tarbean beat")
	_check(director.advance_beat(), "post-slice completes after final advance")
	_check(director.is_slice_complete(), "post-slice completion flag set")
	_check(gs.has_flag("act1_post_slice_completed"), "act1_post_slice_completed lands in GameState")

	# Derived keys keep the default flow's historical keys intact.
	var fresh_gs: Node = load("res://scripts/systems/game_state.gd").new()
	gs.from_dict(fresh_gs.to_dict())
	fresh_gs.queue_free()
	var main_director := SliceDirector.new()
	root.add_child(main_director)
	await process_frame
	main_director.reset_progress()
	_check(gs.quest_states.has("slice_flow_act1_index"),
		"default flow keeps slice_flow_act1 keys")
	_check(main_director.get_current_beat().get("id", "") == "beat_caravan",
		"default flow still starts at caravan")

	director.queue_free()
	main_director.queue_free()


# --- inn interior + tarbean data ---------------------------------------------------

func _test_inn_interior_and_tarbean_data() -> void:
	# The inn interior LDtk map parses with spawn + door metas.
	var project := LdtkLoader.load_project("res://maps/waystone_inn_interior.ldtk")
	_check(not project.is_empty(), "inn interior ldtk parses")
	if not project.is_empty():
		var level := LdtkLoader.build_level_node(project)
		var spawn: Variant = level.get_meta("spawn_position", Vector2.ZERO)
		_check(spawn is Vector2 and (spawn as Vector2) != Vector2.ZERO, "inn interior has spawn")
		var doors: Variant = level.get_meta("doors", [])
		_check(doors is Array and (doors as Array).size() == 1, "inn interior has one door")

	var inn_text := FileAccess.get_file_as_string("res://scenes/world/waystone_inn_interior.tscn")
	_check(inn_text.contains("dialogue_frame_kote.json"), "Kote NPC wired in inn")
	_check(inn_text.contains("dialogue_frame_bast.json"), "Bast NPC wired in inn")
	_check(inn_text.contains("working_light_the_lamp"), "lamp puzzle wired in inn")
	_check(inn_text.contains("caravan_route.tscn"), "inn door exits to caravan route")

	for path in ["res://data/dialogue/dialogue_frame_kote.json", "res://data/dialogue/dialogue_frame_bast.json"]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(parsed is Dictionary, path + " parses")
		if parsed is Dictionary:
			_check(DialogueRunner.validate(parsed).is_empty(), path + " validates clean")

	# Tarbean road teaser beats mirror the opening cutscene contract.
	var parsed_tarbean: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/story/tarbean_road.json"))
	_check(parsed_tarbean is Dictionary, "tarbean_road.json parses")
	if parsed_tarbean is Dictionary:
		var beats: Variant = (parsed_tarbean as Dictionary).get("beats")
		_check(beats is Array and (beats as Array).size() >= 3, "tarbean road has beats")
		if beats is Array:
			var last := (beats as Array)[(beats as Array).size() - 1] as Dictionary
			_check(str(last.get("set_flag", "")) == "flag_tarbean_road_seen", "final tarbean beat sets flag")
			_check(str(last.get("next_scene", "")) == "res://scenes/ui/end_card.tscn",
				"tarbean teaser routes to end card")

	var end_card_text := FileAccess.get_file_as_string("res://scripts/ui/end_card.gd")
	_check(end_card_text.contains("solo_forest.tscn"), "end card continues into post-slice epilogue")
	_check(end_card_text.contains("act1_post_slice_completed"), "end card checks epilogue completion")


# --- title menu + cutscene skip -------------------------------------------------

func _test_title_menu_and_skip() -> void:
	# Title menu scene + script load cleanly.
	_check(load("res://scenes/ui/title_menu.tscn") != null, "title_menu.tscn loads")
	_check(load("res://scripts/ui/title_menu.gd") != null, "title_menu.gd loads")

	var menu_text := FileAccess.get_file_as_string("res://scenes/ui/title_menu.tscn")
	_check(menu_text.contains("NewGameButton"), "menu has New Game button")
	_check(menu_text.contains("ContinueButton"), "menu has Continue button")
	_check(menu_text.contains("QuitButton"), "menu has Quit button")
	_check(menu_text.contains("TitleLabel"), "menu has a title label")

	var script_text := FileAccess.get_file_as_string("res://scripts/ui/title_menu.gd")
	_check(script_text.contains("has_continue_save"), "menu exposes continue-state API")
	_check(script_text.contains("_reset_world"), "menu can reset world state")
	_check(script_text.contains("waystone_inn.tscn"), "New Game routes to Waystone opening")

	# Cutscene skip method exists and accelerates playback.
	var beat_text := FileAccess.get_file_as_string("res://scripts/systems/beat_cutscene.gd")
	_check(beat_text.contains("skip_to_end"), "BeatCutscene exposes skip_to_end")
	_check(beat_text.contains("ui_cancel"), "BeatCutscene listens for skip input")

	var attack_text := FileAccess.get_file_as_string("res://scripts/systems/chandrian_attack.gd")
	_check(attack_text.contains("skip_to_end"), "ChandrianAttack exposes skip_to_end")
	_check(attack_text.contains("ui_cancel"), "ChandrianAttack listens for skip input")

	# Functional cutscene skip — short-duration beats end at the right beat
	# when skip_to_end is called without waiting for timers.
	var skip_beats := {
		"id": "skip_test",
		"beats": [
			{"narration": "One.", "effect": "warm", "duration": 0.05, "set_flag": "flag_skip_one"},
			{"narration": "Two.", "effect": "dim", "duration": 0.05, "set_flag": "flag_skip_two"},
			{"narration": "Three.", "effect": "darkness", "duration": 0.05, "set_flag": "flag_skip_three"},
		],
	}
	var path := "user://test_skip_cutscene.json"
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_string(JSON.stringify(skip_beats))
	writer.close()

	if root.get_node_or_null("GameState") == null:
		var gs_init: Node = load("res://scripts/systems/game_state.gd").new()
		gs_init.name = "GameState"
		root.add_child(gs_init)

	var cutscene := BeatCutscene.new()
	cutscene.auto_start = false
	cutscene.beats_path = path
	root.add_child(cutscene)
	var finished_ids := []
	cutscene.sequence_finished.connect(func(id: String) -> void: finished_ids.append(id))
	cutscene.start_sequence()
	_check(not cutscene.is_sequence_complete(), "cutscene not complete mid-play")
	cutscene.skip_to_end()
	_check(cutscene.is_sequence_complete(), "skip_to_end completes cutscene")
	_check(finished_ids.size() == 1 and finished_ids[0] == "skip_test", "sequence_finished fired on skip")
	var gs := root.get_node_or_null("GameState")
	_check(gs.has_flag("flag_skip_one"), "skip applies first beat flag")
	_check(gs.has_flag("flag_skip_three"), "skip applies last beat flag")
	cutscene.queue_free()

	# Main scene now points at the title menu.
	var project_text := FileAccess.get_file_as_string("res://project.godot")
	_check(project_text.contains("title_menu.tscn"), "main scene is title menu")


# --- Settings + Credits -------------------------------------------------------

func _test_settings_and_credits() -> void:
	# Settings autoload loads + owns its bus topology.
	var settings_path := "res://scripts/systems/settings.gd"
	_check(load(settings_path) != null, "settings.gd loads")
	var settings_text := FileAccess.get_file_as_string(settings_path)
	_check(settings_text.contains("min_volume_db"), "settings exposes volume bounds")
	_check(settings_text.contains("font_scale_options"), "settings exposes font scale options")
	_check(settings_text.contains("colorblind_mode"), "settings exposes colorblind toggle")
	_check(settings_text.contains("colorblind_adjusted"), "settings exposes colorblind adjuster")

	var project := FileAccess.get_file_as_string("res://project.godot")
	_check(project.contains('Settings="*res://scripts/systems/settings.gd"'), "Settings registered as autoload")

	var music_manifest := FileAccess.get_file_as_string("audio/audio-manifest.json")
	_check(music_manifest.contains("MUS_RUH_CAMP"), "MUS_RUH_CAMP published after approval")
	_check(music_manifest.contains("MUS_TARBEAN"), "MUS_TARBEAN published after approval")

	# Settings menu / credits screen assets.
	_check(load("res://scenes/ui/settings_menu.tscn") != null, "settings_menu.tscn loads")
	_check(load("res://scripts/ui/settings_menu.gd") != null, "settings_menu.gd loads")
	_check(load("res://scenes/ui/credits_screen.tscn") != null, "credits_screen.tscn loads")
	_check(load("res://scripts/ui/credits_screen.gd") != null, "credits_screen.gd loads")

	# Title menu wired to both secondary entries.
	var menu_text := FileAccess.get_file_as_string("res://scripts/ui/title_menu.gd")
	_check(menu_text.contains("settings_menu.tscn"), "title menu routes to Settings")
	_check(menu_text.contains("credits_screen.tscn"), "title menu routes to Credits")


# --- Chronicler + ExplorationMap ----------------------------------------------

func _test_chronicler_and_map() -> void:
	# Journal screen + map renderer + overlay wiring.
	_check(load("res://scenes/ui/journal_screen.tscn") != null, "journal_screen.tscn loads")
	_check(load("res://scripts/ui/journal_screen.gd") != null, "journal_screen.gd loads")
	_check(load("res://scripts/ui/map_renderer.gd") != null, "map_renderer.gd loads")
	_check(load("res://scripts/ui/journal_overlay.gd") != null, "journal_overlay.gd loads")

	var project := FileAccess.get_file_as_string("res://project.godot")
	_check(project.contains('ChroniclerJournal="'), "ChroniclerJournal autoload registered")
	_check(project.contains('ExplorationMap="'), "ExplorationMap autoload registered")
	_check(project.contains('JournalOverlay="'), "JournalOverlay autoload registered")
	_check(project.contains('journal=') and project.contains("keycode\":74"), "journal input action bound to J")

	# Templates the writer uses are present in chronicler_journal.
	var cj_text := FileAccess.get_file_as_string("res://scripts/systems/chronicler_journal.gd")
	_check(cj_text.contains("threat_resolved"), "journal has threat template")
	_check(cj_text.contains("puzzle_solved"), "journal has puzzle template")
	_check(cj_text.contains("visit_first"), "journal has visit template")
	_check(cj_text.contains("beat_solo_survive"), "journal has solo-survive template")
	_check(cj_text.contains("beat_tarbean_road"), "journal has tarbean template")

	# Exploration map populates from scene_registry.
	var registry := FileAccess.get_file_as_string("res://data/journal/scene_registry.json")
	_check(registry.contains("waystone_inn"), "scene registry has Waystone")
	_check(registry.contains("solo_forest"), "scene registry has solo_forest")
	_check(registry.contains("tarbean_road"), "scene registry has tarbean_road")

	# Functional smoke for ChroniclerJournal add_event idempotency.
	if root.get_node_or_null("GameState") == null:
		var gs_init: Node = load("res://scripts/systems/game_state.gd").new()
		gs_init.name = "GameState"
		root.add_child(gs_init)
	var journal: Node = load("res://scripts/systems/chronicler_journal.gd").new()
	root.add_child(journal)
	await process_frame
	journal.add_event("beat_attack", {})
	var first_count: int = journal.entry_count()
	journal.add_event("beat_attack", {})
	var second_count: int = journal.entry_count()
	_check(second_count == first_count, "journal dedupes identical events")
	journal.clear()
	journal.queue_free()


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
	_check(
		str(last.get("next_scene", "")) == "res://scenes/world/caravan_route.tscn",
		"final beat routes into illustrated prologue caravan handoff"
	)
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

	var caravan_text := FileAccess.get_file_as_string("res://scenes/world/caravan_route.tscn")
	_check(caravan_text.contains("working_split_boulder"), "caravan wires boulder target")
	_check(caravan_text.contains("threat_road_dogs"), "caravan hosts road dogs threat trigger")
	_check(caravan_text.contains("combat_tutorial.tscn"), "caravan door leads to combat tutorial")

	_check(ResourceLoader.exists("res://scenes/world/combat_tutorial.tscn"), "combat tutorial scene exists")
	_check(ResourceLoader.exists("res://scripts/ui/threat_panel.gd"), "ThreatPanel script exists")
	_check(ResourceLoader.exists("res://scripts/ui/sympathy_puzzle_panel.gd"), "SympathyPuzzlePanel script exists")
	_check(load("res://scenes/world/combat_tutorial.tscn") != null, "combat tutorial scene loads")
