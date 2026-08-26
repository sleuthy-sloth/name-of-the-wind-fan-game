class_name WorldScene
extends Node2D

## WorldScene
# Shared builder for LDtk-backed playable locations (GDD Phase 1/2 polish).
# Replaces the per-scene inline scripts so every location gets the same
# treatment: level build, player spawn, doors, layered looping ambience,
# time-of-day canvas tint, and schedule-driven troupe placement.

@export var ldtk_path: String = ""
@export var door_target_scene: String = ""
## Logical audio events played as looping layers (AMB_*).
@export var ambience_events: Array[String] = []
@export var ambience_volume_db: float = -12.0
## Spawn scheduled NPCs whose ScheduleSystem location resolves here.
@export var spawn_troupe := false
## Apply GameState.time_block canvas tint.
@export var tint_enabled := true
## Out-of-combat sympathy puzzles placed into this scene.
## Entries: {working_id: String, display_name: String, position: Vector2,
##           obstacle_path: String, move_offset: Vector2}
@export var sympathy_targets: Array[Dictionary] = []
## Additional scene doors beyond the LDtk Door entity.
## Entries: {position: Vector2, target_scene: String}
@export var extra_doors: Array[Dictionary] = []
## GDD §7.5 threats placed into this scene (combat found throughout the game).
## Entries: {threat_id: String, display_name: String, position: Vector2}
@export var threat_triggers: Array[Dictionary] = []

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const DOOR_SCENE_SCRIPT := "res://scripts/systems/scene_door.gd"
const SYMPATHY_TARGET_SCRIPT := "res://scripts/world/sympathy_target.gd"
const THREAT_TRIGGER_SCRIPT := "res://scripts/world/threat_trigger.gd"

func _scene_id_from_path() -> String:
	if scene_file_path.is_empty():
		return ""
	var idx: int = scene_file_path.rfind("/")
	if idx == -1:
		return scene_file_path.trim_suffix(".tscn")
	var tail := scene_file_path.substr(idx + 1)
	return tail.trim_suffix(".tscn")

func _note_scene_visited() -> void:
	var scene_id := _scene_id_from_path()
	if scene_id.is_empty():
		return
	var map := get_node_or_null("/root/ExplorationMap")
	var journal := get_node_or_null("/root/ChroniclerJournal")
	if map != null:
		var was_first := (map as ExplorationMap).visit(scene_id)
	if journal != null:
		(journal as ChroniclerJournal).note_visit(scene_id)

const TINT_BY_BLOCK := {
	"morning": Color(1.0, 0.96, 0.88),
	"afternoon": Color(1.0, 1.0, 1.0),
	"evening": Color(1.0, 0.85, 0.69),
	"night": Color(0.55, 0.60, 0.78),
}

func _ready() -> void:
	if ldtk_path.is_empty():
		push_error("WorldScene: ldtk_path is empty on %s" % name)
		return

	_note_scene_visited()

	var project := LdtkLoader.load_project(ldtk_path)
	if project.is_empty():
		push_error("WorldScene: failed to load %s" % ldtk_path)
		return
	var level := LdtkLoader.build_level_node(project)
	add_child(level)

	var spawn_position: Variant = level.get_meta("spawn_position", Vector2.ZERO)
	if not spawn_position is Vector2:
		spawn_position = Vector2.ZERO

	var player_scene := load(PLAYER_SCENE) as PackedScene
	if player_scene != null:
		var player := player_scene.instantiate() as CharacterBody2D
		player.position = spawn_position as Vector2
		add_child(player)

	var doors: Variant = level.get_meta("doors", [])
	if doors is Array:
		for door_data: Variant in doors:
			if door_data is Dictionary:
				_create_door(door_data as Dictionary)

	for extra: Variant in extra_doors:
		if extra is Dictionary and (extra as Dictionary).has("target_scene"):
			_create_door(extra as Dictionary)

	if not sympathy_targets.is_empty():
		_setup_sympathy_targets()

	if not threat_triggers.is_empty():
		_setup_threat_triggers()

	_setup_ambience()
	_setup_tint()
	if spawn_troupe:
		_spawn_scheduled_npcs(spawn_position as Vector2)

func _create_door(data: Dictionary) -> void:
	var door := Area2D.new()
	door.name = "Door"
	var script := load(DOOR_SCENE_SCRIPT) as GDScript
	if script != null:
		door.set_script(script)
		var target: Variant = data.get("target_scene", door_target_scene)
		door.set("target_scene", str(target))
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	door.add_child(collision)
	var pos: Variant = data.get("position", Vector2.ZERO)
	if pos is Vector2:
		door.position = pos as Vector2
	add_child(door)

func _setup_sympathy_targets() -> void:
	var panel := SympathyPuzzlePanel.new()
	panel.name = "SympathyPuzzlePanel"
	add_child(panel)
	for entry: Variant in sympathy_targets:
		if not entry is Dictionary:
			continue
		var data := entry as Dictionary
		var script := load(SYMPATHY_TARGET_SCRIPT) as GDScript
		if script == null:
			continue
		var target := Area2D.new()
		target.set_script(script)
		target.name = "SympathyTarget_" + str(data.get("working_id", "unnamed"))
		target.position = data.get("position", Vector2.ZERO) as Vector2
		target.set("working_id", str(data.get("working_id", "")))
		target.set("display_name", str(data.get("display_name", "")))
		var obstacle_ref := str(data.get("obstacle_path", ""))
		if not obstacle_ref.is_empty():
			target.set("obstacle_path", NodePath(obstacle_ref))
		target.set("move_offset", data.get("move_offset", Vector2.ZERO) as Vector2)
		add_child(target)
		if target.has_signal("puzzle_requested"):
			(target as Area2D).connect(
				"puzzle_requested",
				func(t) -> void: _open_sympathy_puzzle(panel, t)
			)

func _open_sympathy_puzzle(panel: SympathyPuzzlePanel, target: Area2D) -> void:
	if panel.is_open():
		return
	var puzzle := target.call("build_puzzle") as SympathyPuzzle
	if puzzle == null or puzzle.def.is_empty():
		push_warning("WorldScene: no working def for '%s'" % target.name)
		return
	var gs := get_node_or_null("/root/GameState")
	panel.open_for(puzzle, gs if gs != null else self)

func _setup_threat_triggers() -> void:
	var panel := ThreatPanel.new()
	panel.name = "ThreatPanel"
	add_child(panel)
	for entry: Variant in threat_triggers:
		if not entry is Dictionary:
			continue
		var data := entry as Dictionary
		var script := load(THREAT_TRIGGER_SCRIPT) as GDScript
		if script == null:
			continue
		var trigger := Area2D.new()
		trigger.set_script(script)
		trigger.name = "ThreatTrigger_" + str(data.get("threat_id", "unnamed"))
		trigger.position = data.get("position", Vector2.ZERO) as Vector2
		trigger.set("threat_id", str(data.get("threat_id", "")))
		trigger.set("display_name", str(data.get("display_name", "")))
		add_child(trigger)
		if trigger.has_signal("threat_requested"):
			(trigger as Area2D).connect(
				"threat_requested",
				func(t) -> void: _open_threat(panel, t)
			)

func _open_threat(panel: ThreatPanel, trigger) -> void:
	if panel.is_open():
		return
	var threat := trigger.call("build_threat") as ThreatEncounter
	if threat == null or threat.def.is_empty():
		push_warning("WorldScene: no threat def for '%s'" % trigger.name)
		return
	var gs := get_node_or_null("/root/GameState")
	panel.open_for(threat, gs if gs != null else self)
	panel.encounter_finished.connect(
		func(_outcome: Dictionary) -> void:
			var last: Dictionary = panel.get_last_outcome()
			trigger.call("resolve_after_encounter", threat, last)
	)

func _setup_ambience() -> void:
	for event_id in ambience_events:
		var stream := AudioLibrary.stream_for(event_id)
		if stream == null:
			continue
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		var player := AudioStreamPlayer.new()
		player.name = "Ambience_" + event_id
		player.stream = stream
		player.volume_db = ambience_volume_db
		player.autoplay = true
		add_child(player)

func _setup_tint() -> void:
	if not tint_enabled:
		return
	var gs := get_node_or_null("/root/GameState")
	var block := "afternoon"
	if gs != null:
		block = str(gs.get("time_block"))
	var tint := CanvasModulate.new()
	tint.name = "TimeTint"
	tint.color = TINT_BY_BLOCK.get(block, TINT_BY_BLOCK["afternoon"])
	add_child(tint)

func _spawn_scheduled_npcs(fallback_center: Vector2) -> void:
	var schedules := get_node_or_null("/root/ScheduleSystem")
	if schedules == null:
		return
	var scene_path := scene_file_path
	var index := 0
	for npc_id_v: Variant in schedules.call("get_npc_ids"):
		var npc_id := str(npc_id_v)
		var location: Dictionary = schedules.call("resolve_now", npc_id)
		if str(location.get("scene", "")) != scene_path:
			continue
		var packed := load(_scene_for_npc(npc_id)) as PackedScene
		if packed == null:
			continue
		var npc := packed.instantiate() as Node2D
		npc.position = _position_for(location, fallback_center, index)
		add_child(npc)
		index += 1

## char_troupe_member_01 -> res://scenes/npcs/troupe_member_01.tscn
func _scene_for_npc(npc_id: String) -> String:
	var short := npc_id.trim_prefix("char_")
	return "res://scenes/npcs/%s.tscn" % short

## Marker names resolve against known camp anchors; unknown markers fall back
## to a ring around the player spawn so nobody spawns inside scenery.
func _position_for(location: Dictionary, center: Vector2, index: int) -> Vector2:
	var marker := str(location.get("marker", ""))
	const MARKER_OFFSETS := {
		"marker_campfire": Vector2(72, 8),
		"marker_abenthy_wagon": Vector2(-56, -24),
		"marker_abenthy_workbench": Vector2(-24, -48),
		"marker_arliden_tent": Vector2(104, -32),
		"marker_laurian_tent": Vector2(-88, 24),
	}
	if MARKER_OFFSETS.has(marker):
		return center + (MARKER_OFFSETS[marker] as Vector2)
	var angle := TAU * float(index) / 6.0
	return center + Vector2(cos(angle), sin(angle)) * 88.0
