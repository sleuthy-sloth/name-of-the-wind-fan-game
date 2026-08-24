extends SceneTree

# Simple Alar holder used by tests; production passes the GameState autoload.
class AlarStub:
	extends RefCounted
	var alar: float = 100.0
	var max_alar: float = 100.0

var _failures: int = 0

func _initialize() -> void:
	_run_tests.call_deferred()

func _run_tests() -> void:
	await physics_frame

	print("SYMPATHY_TEST: START")

	_test_formula_cases()
	_test_bench_preview()
	_test_successful_resolution()
	_test_failure_consequence()
	_test_rest_recovery()
	_test_journal_round_trip()

	if _failures == 0:
		print("SYMPATHY_TEST: PASS")
		quit(0)
	else:
		print("SYMPATHY_TEST: FAIL (%d assertion(s) failed)" % _failures)
		quit(1)

func _test_formula_cases() -> void:
	# Case 1: strong source, perfect link, full mastery -> safe and cheap.
	# S=100, L=1.0, M=1.0, R=20, D=1.0, composure=0.0
	# effective = 100 * (0.5+0.5) * (0.6+0.4) = 100
	# cost multiplier = clamp(1 - 0.3 - 0.2, 0.1, 1) = 0.5 -> cost = 10
	# risk = clamp((20-100)/20, 0, 1) * 1 * 1 = 0
	var engine1 := _make_engine(100.0, 1.0, 1.0, 20.0, 1.0, 0.0)
	_assert_approx(engine1.compute_effective_energy(), 100.0, 0.001, "case1 effective_energy")
	_assert_approx(engine1.compute_cost(), 10.0, 0.001, "case1 cost")
	_assert_approx(engine1.compute_risk(), 0.0, 0.001, "case1 risk")

	# Case 2: marginal source, mediocre link, mastery -> risky.
	# S=20, L=0.5, M=0.5, R=30, D=2.0, composure=0.0
	# effective = 20 * 0.75 * 0.8 = 12
	# cost multiplier = clamp(1 - 0.15 - 0.1, 0.1, 1) = 0.75 -> cost = 22.5
	# risk = clamp((30-12)/30, 0, 1) * 2 * 1 = 1.2 -> clamped 1.0
	var engine2 := _make_engine(20.0, 0.5, 0.5, 30.0, 2.0, 0.0)
	_assert_approx(engine2.compute_effective_energy(), 12.0, 0.001, "case2 effective_energy")
	_assert_approx(engine2.compute_cost(), 22.5, 0.001, "case2 cost")
	_assert_approx(engine2.compute_risk(), 1.0, 0.001, "case2 risk")

	# Case 3: decent source, weak link, no mastery, some composure.
	# S=50, L=0.0, M=0.0, R=25, D=1.5, composure=0.2
	# effective = 50 * 0.5 * 0.6 = 15
	# cost multiplier = clamp(1 - 0 - 0, 0.1, 1) = 1 -> cost = 25
	# risk = clamp((25-15)/25, 0, 1) * 1.5 * (1 - 0.1) = 0.4 * 1.5 * 0.9 = 0.54
	var engine3 := _make_engine(50.0, 0.0, 0.0, 25.0, 1.5, 0.2)
	_assert_approx(engine3.compute_effective_energy(), 15.0, 0.001, "case3 effective_energy")
	_assert_approx(engine3.compute_cost(), 25.0, 0.001, "case3 cost")
	_assert_approx(engine3.compute_risk(), 0.54, 0.001, "case3 risk")

func _test_bench_preview() -> void:
	var holder := AlarStub.new()
	var bench: SympathyBench = load("res://scenes/minigames/sympathy_bench.tscn").instantiate()
	root.add_child(bench)
	bench.setup(holder, _sources(), _links(), _targets(), _effects())
	bench.set_source_index(0)
	bench.set_link_index(0)
	bench.set_target_index(0)
	await process_frame

	# The pre-commit panel must expose cost and risk strings before commitment (GDD §24).
	var cost_text: String = bench.cost_label.text
	var risk_text: String = bench.risk_label.text
	_assert_true(cost_text.contains("Cost:"), "bench cost label visible")
	_assert_true(risk_text.contains("Risk:"), "bench risk label visible")
	_assert_true(cost_text.contains("10.0"), "bench cost shows case1 value")
	_assert_true(risk_text.contains("0.0"), "bench risk shows case1 value")

	bench.queue_free()

func _test_successful_resolution() -> void:
	var holder := AlarStub.new()
	holder.alar = 100.0
	var engine := _make_engine(100.0, 1.0, 1.0, 20.0, 1.0, 0.0)
	var preview := engine.resolve(holder, false)
	var expected_cost: float = preview["cost"]
	var result := engine.resolve(holder, true)
	_assert_true(result["success"], "success path succeeds")
	_assert_eq(result["effect_applied"].get("domain"), "light", "success applies payload domain")
	_assert_approx(result["alar_spent"], expected_cost, 0.001, "success spends exactly computed cost")
	_assert_approx(holder.alar, 100.0 - expected_cost, 0.001, "success alar remaining matches holder")

func _test_failure_consequence() -> void:
	# Force failure with risk = 1.0 and insufficient Alar to cover the penalty.
	var holder := AlarStub.new()
	holder.alar = 10.0
	var engine := _make_engine(20.0, 0.5, 0.5, 30.0, 2.0, 0.0)
	var result := engine.resolve(holder, true)
	_assert_false(result["success"], "failure path fails")
	_assert_true(result["failure_consequence"].contains("alar_loss"), "failure consequence includes Alar loss")
	_assert_true(result["failure_consequence"].contains("alar_overdraw"), "overdraw recorded when Alar emptied")
	_assert_eq(holder.alar, 0.0, "holder Alar clamped to zero after overdraw")
	_assert_true(result.has("recovery_minutes"), "recovery delay attached to overdraw")

func _test_rest_recovery() -> void:
	# GDD §13.6 zone rules: safe 40-100%, strained 20-39%, critical 0-19%.
	# Safe zone recovery rate is 1.0x.
	var safe := SympathyEngine.rest_action(50.0, 100.0, 10.0)
	_assert_approx(safe, 60.0, 0.001, "safe zone recovers 1.0x")

	# Strained zone recovery rate is 0.6x.
	var strained := SympathyEngine.rest_action(30.0, 100.0, 10.0)
	_assert_approx(strained, 36.0, 0.001, "strained zone recovers 0.6x")

	# Critical zone recovery rate is 0.25x and caps at max_alar.
	var critical := SympathyEngine.rest_action(10.0, 100.0, 400.0)
	_assert_approx(critical, 100.0, 0.001, "critical zone recovers 0.25x and caps")

func _test_journal_round_trip() -> void:
	var journal := Journal.new()
	journal.add_entry("src_campfire", "lnk_ash", "tgt_lamp", "efx_light", "success")
	journal.add_entry("src_campfire", "lnk_ash", "tgt_lamp", "efx_light", "success")
	journal.add_entry("src_body", "lnk_blood", "tgt_lock", "efx_heat", "failure")
	_assert_eq(journal.entry_count(), 2, "journal dedupes repeated discoveries")

	var data := journal.to_dict()
	var restored := Journal.new()
	restored.from_dict(data)
	_assert_eq(restored.entry_count(), 2, "journal round-trips entry count")
	var entries := restored.list_entries()
	var has_light := false
	var has_heat := false
	for entry: Dictionary in entries:
		if entry["effect_id"] == "efx_light":
			has_light = true
			_assert_eq(entry["attempt_count"], 2, "attempt count accumulated")
		if entry["effect_id"] == "efx_heat":
			has_heat = true
	_assert_true(has_light, "journal preserves light discovery")
	_assert_true(has_heat, "journal preserves heat discovery")

func _make_engine(S: float, L: float, M: float, R: float, D: float, composure: float) -> SympathyEngine:
	var engine := SympathyEngine.new()
	engine.set_source({"id": "src_campfire", "energy": S, "domain": "light"})
	engine.set_link({"id": "lnk_ash", "quality": L, "domains": ["light", "heat"]})
	engine.set_target({"id": "tgt_lamp", "tolerance": R, "domain": "light"})
	engine.set_effect({"id": "efx_light", "cost": R, "domain": "light", "payload": {"domain": "light", "source_dim": 0.2, "target_brighten": 0.5}})
	engine.set_mastery(M)
	engine.set_composure(composure)
	engine.set_difficulty(D)
	return engine

func _sources() -> Array[Dictionary]:
	return [{"id": "src_campfire", "energy": 100.0, "domain": "light"}]

func _links() -> Array[Dictionary]:
	return [{"id": "lnk_ash", "quality": 1.0, "domains": ["light", "heat"]}]

func _targets() -> Array[Dictionary]:
	return [{"id": "tgt_lamp", "tolerance": 20.0, "domain": "light"}]

func _effects() -> Array[Dictionary]:
	return [{"id": "efx_light", "label": "Draw Light", "cost": 20.0, "domain": "light", "payload": {"domain": "light", "source_dim": 0.2, "target_brighten": 0.5}}]

func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("ASSERT FAIL: %s (expected %s, got %s)" % [message, str(expected), str(actual)])
		_failures += 1

func _assert_true(actual: bool, message: String) -> void:
	if not actual:
		push_error("ASSERT FAIL: %s (expected true)" % message)
		_failures += 1

func _assert_false(actual: bool, message: String) -> void:
	if actual:
		push_error("ASSERT FAIL: %s (expected false)" % message)
		_failures += 1

func _assert_approx(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		push_error("ASSERT FAIL: %s (expected %f, got %f)" % [message, expected, actual])
		_failures += 1
