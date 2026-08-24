extends SceneTree

# Minimal Alar holder for SympathyEngine resolution.
class AlarStub:
	extends RefCounted
	var alar: float = 100.0
	var max_alar: float = 100.0

var _failures: int = 0

func _initialize() -> void:
	_run_tests.call_deferred()

func _run_tests() -> void:
	await process_frame

	print("SYMPATHY_LIGHTING_TEST: START")

	_test_light_domain()
	_test_heat_domain()
	_test_audio_feedback()
	_test_demo_scene()

	if _failures == 0:
		print("SYMPATHY_LIGHTING_TEST: PASS")
		quit(0)
	else:
		print("SYMPATHY_LIGHTING_TEST: FAIL (%d assertion(s) failed)" % _failures)
		quit(1)

func _test_light_domain() -> void:
	var result: Dictionary = _make_success_result("light")
	var lighting: SympathyLighting = SympathyLighting.new()
	root.add_child(lighting)
	await process_frame

	var base_source: Color = lighting.get_source_modulate()
	var base_target: Color = lighting.get_target_modulate()
	var base_ambient: Color = lighting.get_ambient_color()

	lighting.apply_instant(result)

	var source: Color = lighting.get_source_modulate()
	var target: Color = lighting.get_target_modulate()
	var ambient: Color = lighting.get_ambient_color()

	_assert_true(source.r < base_source.r and source.g < base_source.g and source.b < base_source.b, "light: source dimmed")
	_assert_true(target.r > base_target.r or target.g > base_target.g or target.b > base_target.b, "light: target brightened")
	_assert_true(ambient.b > base_ambient.b and ambient.r < base_ambient.r, "light: ambient shifted cooler (blue up, red down)")
	_assert_true(lighting.get_mask_layer_count() >= 2, "light: at least 2 layered mask overlays")

	lighting.queue_free()

func _test_heat_domain() -> void:
	var result: Dictionary = _make_success_result("heat")
	var lighting: SympathyLighting = SympathyLighting.new()
	root.add_child(lighting)
	await process_frame

	var base_source: Color = lighting.get_source_modulate()
	var base_target: Color = lighting.get_target_modulate()
	var base_ambient: Color = lighting.get_ambient_color()

	lighting.apply_instant(result)

	var source: Color = lighting.get_source_modulate()
	var target: Color = lighting.get_target_modulate()
	var ambient: Color = lighting.get_ambient_color()

	_assert_true(source.r < base_source.r and source.g < base_source.g and source.b < base_source.b, "heat: source dimmed")
	_assert_true(target.r > base_target.r or target.g > base_target.g or target.b > base_target.b, "heat: target brightened")
	_assert_true(ambient.r > base_ambient.r and ambient.b < base_ambient.b, "heat: ambient shifted warmer (red up, blue down)")
	_assert_true(lighting.get_mask_layer_count() >= 2, "heat: at least 2 layered mask overlays")

	lighting.queue_free()

func _test_audio_feedback() -> void:
	var lighting: SympathyLighting = SympathyLighting.new()
	root.add_child(lighting)
	await process_frame

	var player: AudioStreamPlayer = lighting.get_node_or_null("FeedbackPlayer")
	_assert_true(player != null, "feedback player exists")

	lighting.play_feedback("light")
	var stream_light: AudioStreamWAV = player.stream as AudioStreamWAV
	lighting.play_feedback("heat")
	var stream_heat: AudioStreamWAV = player.stream as AudioStreamWAV

	_assert_true(stream_light != null and stream_heat != null, "feedback streams are AudioStreamWAV")
	_assert_true(stream_light.data != stream_heat.data, "light and heat feedback streams differ")
	_assert_eq(stream_light.format, AudioStreamWAV.FORMAT_16_BITS, "feedback stream is 16-bit PCM")
	_assert_true(lighting.get_last_feedback_frequency() > 0.0, "last feedback frequency recorded")

	lighting.queue_free()

func _test_demo_scene() -> void:
	var demo: Node2D = load("res://scenes/minigames/sympathy_lighting_demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame

	var lighting: SympathyLighting = demo.get_node_or_null("SympathyLighting")
	_assert_true(lighting != null, "demo scene contains SympathyLighting node")
	_assert_true(lighting.has_node("CampfireSource"), "demo scene has CampfireSource endpoint")
	_assert_true(lighting.has_node("LampTarget"), "demo scene has LampTarget endpoint")

	demo.queue_free()

func _make_success_result(domain: String) -> Dictionary:
	var holder := AlarStub.new()
	var engine := SympathyEngine.new()
	engine.set_source({"id": "src_campfire", "energy": 100.0, "domain": domain})
	engine.set_link({"id": "lnk_ash", "quality": 1.0, "domains": ["light", "heat"]})
	engine.set_target({"id": "tgt_lamp", "tolerance": 20.0, "domain": domain})
	var payload: Dictionary = {"domain": domain, "source_dim": 0.2, "target_brighten": 0.5}
	engine.set_effect({"id": "efx_%s" % domain, "cost": 20.0, "domain": domain, "payload": payload})
	engine.set_mastery(1.0)
	engine.set_composure(0.0)
	engine.set_difficulty(1.0)

	var result: Dictionary = engine.resolve(holder, true)
	_assert_true(result["success"], "engine resolves %s successfully" % domain)
	_assert_eq(result["effect_applied"].get("domain"), domain, "resolved payload domain matches")
	return result

func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("ASSERT FAIL: %s (expected %s, got %s)" % [message, str(expected), str(actual)])
		_failures += 1

func _assert_true(actual: bool, message: String) -> void:
	if not actual:
		push_error("ASSERT FAIL: %s (expected true)" % message)
		_failures += 1
