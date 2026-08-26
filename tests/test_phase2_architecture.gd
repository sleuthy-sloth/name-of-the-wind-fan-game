extends SceneTree

## test_phase2_architecture.gd
## Headless verification of the GDD Phase 2 modular architecture pass:
## QuestManager lifecycle, RelationshipManager tiers, ScheduleSystem
## resolution, MinigameHost flow, and SaveManager v1->v2 migration with
## save_contributors. Prints PHASE2_ARCH_TEST: PASS/FAIL.

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _run() -> void:
	await _test_quest_manager()
	await _test_relationship_manager()
	await _test_schedule_system()
	await _test_minigame_host()
	await _test_save_migration()

	if _failures == 0:
		print("PHASE2_ARCH_TEST: PASS (%d/%d checks)" % [_checks, _checks])
	else:
		print("PHASE2_ARCH_TEST: FAIL (%d/%d checks passed)" % [_checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)


func _qm() -> Node:
	return get_root().get_node_or_null("/root/QuestManager")

func _rm() -> Node:
	return get_root().get_node_or_null("/root/RelationshipManager")

func _ss() -> Node:
	return get_root().get_node_or_null("/root/ScheduleSystem")

func _gs() -> Node:
	return get_root().get_node_or_null("/root/GameState")

func _sm() -> Node:
	return get_root().get_node_or_null("/root/SaveManager")


# --- QuestManager -------------------------------------------------------------

func _test_quest_manager() -> void:
	var qm := _qm()
	_check(qm != null, "QuestManager autoload present")
	if qm == null:
		return

	var loaded: int = qm.call("load_all")
	_check(loaded >= 1, "at least one quest definition loaded")
	var errors: Array = qm.call("validate")
	for e in errors:
		printerr("quest validate: " + str(e))
	_check(errors.is_empty(), "quest definitions validate cleanly")

	var qid := "quest_act1_camp_duties"
	var gs := _gs()
	gs.set("money", gs.get("money"))  # touch to ensure alive
	gs.call("set_flag", "flag_act1_abenthy_tutorial_done")

	var started: bool = qm.call("start_quest", qid)
	_check(started, "quest starts")
	_check(qm.call("is_active", qid), "quest active after start")
	_check(str(qm.call("current_stage_id", qid)) == "stage_performance",
		"flag objective auto-completes stage 1 via chained evaluation")
	_check(gs.has_flag("flag_act1_camp_duties_started"),
		"stage on_complete set_flags applied")
	_check(not gs.has_flag("flag_act1_camp_duties_complete"),
		"final stage not yet complete")

	# Complete the relationship objective through the manager integration.
	var rm := _rm()
	rm.call("adjust_relationship", "char_troupe_audience", 5.0)
	_check(qm.call("is_completed", qid),
		"relationship objective completes final stage via notify hook")
	_check(gs.has_flag("flag_act1_camp_duties_complete"),
		"final stage flags applied")
	_check(int(gs.reputation.get("edema_ruh", 0)) == 5,
		"reputation reward applied exactly once")

	var again: bool = qm.call("start_quest", qid)
	_check(not again, "completed quest cannot restart")


# --- RelationshipManager ------------------------------------------------------

func _test_relationship_manager() -> void:
	var rm := _rm()
	_check(rm != null, "RelationshipManager autoload present")
	if rm == null:
		return
	var gs := _gs()

	var value: float = rm.call("adjust_relationship", "char_test_dummy", 150.0)
	_check(value == 100.0, "relationship clamps to +100")
	_check(String(rm.call("tier_of", "char_test_dummy")) == "close",
		"+100 reads as 'close' tier")

	rm.call("adjust_relationship", "char_test_dummy", -260.0)
	_check(float(gs.relationships.get("char_test_dummy", 0.0)) == -100.0,
		"relationship clamps to -100")
	_check(String(rm.call("tier_of", "char_test_dummy")) == "hostile",
		"-100 reads as 'hostile' tier")

	rm.call("set_relationship", "char_test_dummy", 10.0)
	_check(String(rm.call("tier_of", "char_test_dummy")) == "neutral",
		"set_relationship lands in neutral band")
	_check(bool(rm.call("meets_threshold", "char_test_dummy", 10.0)),
		"meets_threshold inclusive at boundary")

	var rep: int = rm.call("adjust_reputation", "test_group", 7)
	_check(rep == 7, "reputation accumulates")
	_check(String(rm.call("reputation_standing", "test_group")) == "unknown",
		"standing label for rep 7 is 'unknown'")
	rm.call("adjust_reputation", "test_group", 30)
	_check(String(rm.call("reputation_standing", "test_group")) == "respected",
		"standing label for rep 37 is 'respected'")

	gs.relationships.erase("char_test_dummy")
	gs.reputation.erase("test_group")


# --- ScheduleSystem -----------------------------------------------------------

func _test_schedule_system() -> void:
	var ss := _ss()
	_check(ss != null, "ScheduleSystem autoload present")
	if ss == null:
		return
	_check(ss.call("load_all") >= 3, "schedule entries loaded")
	_check((ss.call("validate") as Array).is_empty(), "schedules validate cleanly")

	var morning: Dictionary = ss.call("resolve", "char_abenthy", 1, 2, "morning")
	_check(String(morning.get("marker", "")) == "marker_abenthy_workbench",
		"morning override applies")
	var default_loc: Dictionary = ss.call("resolve", "char_abenthy", 1, 2, "afternoon")
	_check(String(default_loc.get("marker", "")) == "marker_abenthy_wagon",
		"default used outside override window")
	var hidden: Dictionary = ss.call("resolve", "char_abenthy", 1, 7, "night")
	_check(hidden.is_empty(), "hide:true removes NPC from that day")
	var unknown: Dictionary = ss.call("resolve", "char_nobody", 1, 1, "morning")
	_check(unknown.is_empty(), "unknown NPC resolves empty")

	# resolve_now reflects live GameState time_block.
	var gs := _gs()
	var original_block: String = gs.get("time_block")
	gs.set("time_block", "evening")
	var evening: Dictionary = ss.call("resolve_now", "char_arliden")
	_check(String(evening.get("marker", "")) == "marker_arliden_tent",
		"resolve_now honors live time block")
	gs.set("time_block", original_block)


# --- MinigameHost -------------------------------------------------------------

class DummyMinigame extends Node:
	signal finished(result: Dictionary)
	var result_sent := false
	func get_minigame_id() -> String:
		return "dummy_test_game"
	func setup(params: Dictionary) -> void:
		set_meta("params_seed", params.get("seed", 0))
	func finish_game(score: int) -> void:
		result_sent = true
		finished.emit({"score": score})


func _test_minigame_host() -> void:
	var host := MinigameHost.new()
	get_root().add_child(host)
	_check(host.is_in_group("minigame_host"), "host joins its group")

	var game := DummyMinigame.new()
	var started: bool = host.start_with_node(game, {"seed": 42})
	_check(started, "minigame starts")
	_check(host.is_running(), "host reports running")
	_check(host.current_minigame_id() == "dummy_test_game",
		"minigame id read from game")
	_check(game.get_meta("params_seed") == 42, "setup params delivered")

	var second := host.start_with_node(DummyMinigame.new())
	_check(not second, "second concurrent start refused")

	var got_result := {}
	host.minigame_finished.connect(func(id: String, result: Dictionary) -> void:
		got_result["id"] = id
		got_result["result"] = result)

	game.finish_game(7)
	await process_frame
	_check(got_result.get("id") == "dummy_test_game", "finish signal routed with id")
	_check(got_result.get("result", {}).get("score") == 7, "result payload intact")
	_check(not host.is_running(), "host idle after finish")

	var cancel_target := DummyMinigame.new()
	host.start_with_node(cancel_target)
	var cancelled := {}
	host.minigame_cancelled.connect(func(id: String) -> void: cancelled["id"] = id)
	host.cancel()
	_check(cancelled.get("id") == "dummy_test_game", "cancel emits with id")
	_check(not host.is_running(), "host idle after cancel")

	host.queue_free()


# --- SaveManager migration ----------------------------------------------------

class StubContributor extends Node:
	var payload := {}
	func save_state_id() -> String:
		return "stub_system"
	func collect_save_state() -> Dictionary:
		return {"value": payload.get("value", "")}
	func apply_save_state(d: Dictionary) -> void:
		payload = d.duplicate()


func _test_save_migration() -> void:
	var sm := _sm()
	var gs := _gs()
	_check(sm != null, "SaveManager autoload present")
	if sm == null:
		return
	_check(int(sm.get("SAVE_VERSION")) == 2, "SAVE_VERSION bumped to 2")

	var contributor := StubContributor.new()
	contributor.payload = {"value": "persisted"}
	get_root().add_child(contributor)
	contributor.add_to_group("save_contributors")

	sm.call("delete_save", 9)
	_check(sm.call("save_game", 9), "v2 save writes")
	sm.call("delete_save", 9)

	# Craft a v1 payload directly and confirm migration path.
	var v1_payload := {
		"version": 1,
		"saved_at": "2026-08-25T00:00:00",
		"state": {
			"act": 1, "day": 3, "time_block": "evening",
			"alar": 50.0, "max_alar": 100.0, "money": 12,
			"relationships": {}, "reputation": {}, "quest_states": {},
			"world_flags": {},
		},
		"scene_path": "",
	}
	var migrated: Variant = sm._migrations[1].call(v1_payload)
	_check(migrated != null and int(migrated.get("version")) == 2,
		"v1->v2 migration upgrades version")
	_check((migrated as Dictionary).has("managers"), "migration adds managers bucket")

	# Round-trip through real files with contributor state.
	sm.call("save_game", 9)
	# Mutate then reload; contributor state must be restored by key.
	contributor.payload = {"value": "mutated"}
	var ok: bool = sm.call("load_game", 9)
	_check(ok, "v2 load succeeds")
	_check(contributor.payload.get("value") == "persisted",
		"contributor state restored under save_state_id key")
	sm.call("delete_save", 9)

	# Newer-than-current versions fail closed.
	var future_path: String = sm.call("slot_path", 9)
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open(future_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 99, "state": {}}))
	f.close()
	_check(not sm.call("load_game", 9), "future save version fails closed")
	sm.call("delete_save", 9)

	get_root().remove_child(contributor)
	contributor.queue_free()
