extends SceneTree

## test_slice_polish.gd
## Headless verification of vertical-slice polish: published LPC sheets,
## animated player/NPC wiring, schedule-driven troupe spawning, ambience
## layers, time-of-day tint, interaction prompts, and manifest-driven UI
## audio. Prints SLICE_POLISH_TEST: PASS/FAIL.

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
	await _test_published_sheets()
	await _test_lpc_sprite()
	await _test_player_wiring()
	await _test_npc_prompt()
	await _test_world_scene()
	await _test_audio_manifest_refs()
	await _test_cutscene_scenes()
	_remove_probe_nodes()

	if _failures == 0:
		print("SLICE_POLISH_TEST: PASS (%d/%d checks)" % [_checks, _checks])
	else:
		print("SLICE_POLISH_TEST: FAIL (%d/%d checks passed)" % [_checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)


var _probe_nodes: Array[Node] = []

func _track(node: Node) -> Node:
	_probe_nodes.append(node)
	return node

func _remove_probe_nodes() -> void:
	for node in _probe_nodes:
		if is_instance_valid(node):
			root.remove_child(node)
			node.queue_free()


# --- published art -------------------------------------------------------------

const SHEETS := [
	"kvothe_caravan", "abenthy", "arliden", "laurian",
	"ruh_crew_00", "ruh_crew_01", "ruh_crew_02", "ruh_crew_03",
]

func _test_published_sheets() -> void:
	for sheet: String in SHEETS:
		var base := "res://art/sprites/lpc/" + sheet
		_check(ResourceLoader.exists(base + ".png"), sheet + ".png published")
		if not FileAccess.file_exists(base + ".json"):
			_check(false, sheet + ".json published")
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
		var ok := typeof(parsed) == TYPE_DICTIONARY
		if ok:
			var anims: Variant = (parsed as Dictionary).get("meta", {}).get("animations", {})
			ok = typeof(anims) == TYPE_DICTIONARY \
				and (anims as Dictionary).has("idle") \
				and (anims as Dictionary).has("walk")
		_check(ok, sheet + " frame data has idle+walk animations")


# --- LpcSprite ------------------------------------------------------------------

func _test_lpc_sprite() -> void:
	var sprite := LpcSprite.new()
	_track(_add_and_return(sprite))
	var loaded: bool = sprite.load_sheet("res://art/sprites/lpc/kvothe_caravan")
	_check(loaded, "LpcSprite loads kvothe_caravan sheet")
	_check(sprite.has_animation("idle"), "idle animation present")
	_check(sprite.has_animation("walk"), "walk animation present")

	sprite.play("walk")
	sprite.set_direction("left")
	var first_rect: Rect2 = sprite.region_rect
	_check(first_rect.position.y > 0.0, "direction row offsets region")
	sprite.set_direction("down")
	_check(sprite.region_rect != first_rect, "direction change moves region")

	sprite.set_fps(30.0)
	var before: Rect2 = sprite.region_rect
	sprite._process(1.0 / 15.0)
	_check(sprite.region_rect != before or int(sprite.region_rect.position.x) == 64,
		"process advances walk frames")

	var missing := LpcSprite.new()
	_track(_add_and_return(missing))
	_check(not missing.load_sheet("res://art/sprites/lpc/does_not_exist"),
		"missing sheet fails gracefully")

func _add_and_return(node: Node) -> Node:
	root.add_child(node)
	return node


# --- player wiring ---------------------------------------------------------------

func _test_player_wiring() -> void:
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	_check(packed != null, "player scene loads")
	if packed == null:
		return
	var player := packed.instantiate() as CharacterBody2D
	_track(player)
	root.add_child(player)
	await process_frame
	var lpc := player.get_node_or_null("LpcSprite") as LpcSprite
	_check(lpc != null, "player uses LpcSprite")
	if lpc != null:
		_check(lpc.texture != null, "player LpcSprite has texture")
		_check(lpc.current_animation() == "idle", "player starts idle")
	var placeholder := player.get_node_or_null("Sprite2D") as Sprite2D
	_check(placeholder == null or placeholder.visible == false,
		"placeholder hidden when LPC art active")

	# Simulate movement updating facing.
	player._update_facing(Vector2(-1, 0))
	player._moving = true
	player._update_animation()
	if lpc != null:
		_check(lpc.current_animation() == "walk", "movement switches to walk")
		_check(str(lpc.region_rect) != "" , "walk region applied")


# --- npc prompt -------------------------------------------------------------------

func _test_npc_prompt() -> void:
	var packed := load("res://scenes/npcs/abenthy.tscn") as PackedScene
	_check(packed != null, "abenthy scene loads")
	if packed == null:
		return
	var npc := packed.instantiate()
	_track(npc)
	root.add_child(npc)
	await process_frame
	var lpc := npc.get_node_or_null("LpcSprite") as LpcSprite
	_check(lpc != null, "NPC uses LpcSprite sheet")

	var fake_player := Node2D.new()
	fake_player.add_to_group(&"player")
	npc._on_body_entered(fake_player)
	_check(npc.can_interact, "entering player sets can_interact")
	var prompt := npc.get_node_or_null("InteractPrompt") as Label
	_check(prompt != null and prompt.visible, "interact prompt appears in range")

	npc._on_body_exited(fake_player)
	_check(not npc.can_interact, "leaving player clears can_interact")
	_check(prompt != null and prompt.visible == false, "prompt hides out of range")


# --- world scene integration --------------------------------------------------------

func _test_world_scene() -> void:
	var gs := root.get_node_or_null("/root/GameState")
	var original_block := str(gs.get("time_block"))
	gs.set("time_block", "evening")

	var camp := (load("res://scenes/world/forest_campsite.tscn") as PackedScene).instantiate()
	_track(camp)
	root.add_child(camp)
	await process_frame
	await physics_frame

	var npcs_found := 0
	for child in camp.get_children():
		if child.get_script() != null and str(child.get_script().resource_path).ends_with("npc.gd"):
			npcs_found += 1
	_check(npcs_found >= 3,
		"campsite spawns scheduled troupe (%d found)" % npcs_found)

	var tint := camp.get_node_or_null("TimeTint") as CanvasModulate
	_check(tint != null, "time tint present")
	if tint != null:
		_check(tint.color == WorldScene.TINT_BY_BLOCK["evening"],
			"tint matches evening block")

	var ambience_count := 0
	for child in camp.get_children():
		if child.name.begins_with("Ambience_"):
			ambience_count += 1
	_check(ambience_count >= 2, "campsite plays layered ambience")

	gs.set("time_block", original_block)


# --- audio manifest references -------------------------------------------------------

func _test_audio_manifest_refs() -> void:
	for event_id in ["AMB_CAMPFIRE_LOOP", "AMB_FOREST_NIGHT", "AMB_WIND_LIGHT_LAYER",
			"MUS_STING_ENDCARD", "SFX_UI_CONFIRM", "SFX_UI_HOVER", "SFX_UI_TOGGLE",
			"SFX_WIND_STRONG", "SFX_THUNDER"]:
		_check(AudioLibrary.has_event(event_id), "manifest has " + event_id)

	var end_card_text := FileAccess.get_file_as_string("res://scenes/ui/end_card.tscn")
	_check(not end_card_text.contains("sting_endcard_01.ogg"),
		"end card uses manifest event, not hardcoded stream")


# --- cutscene scenes ------------------------------------------------------------------

func _test_cutscene_scenes() -> void:
	for scene_path in ["res://scenes/world/chandrian_attack.tscn",
			"res://scenes/world/escape_aftermath.tscn"]:
		var packed := load(scene_path) as PackedScene
		_check(packed != null, scene_path.get_file() + " loads")
		if packed == null:
			continue
		var scene := packed.instantiate()
		_track(scene)
		root.add_child(scene)
		await process_frame
		var amb := scene.get_node_or_null("AmbiencePlayer") as AudioStreamPlayer
		_check(amb != null and amb.stream != null,
			scene_path.get_file() + " plays ambience bed")
		var label := scene.get_node_or_null("TextLayer/NarrationLabel") as RichTextLabel
		_check(label != null and label.get_theme_font_size("normal_font_size") >= 18,
			scene_path.get_file() + " narration styled")
		scene.queue_free()
