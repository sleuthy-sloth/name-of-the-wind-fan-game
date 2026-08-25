## AudioLibrary
# Manifest-driven audio event lookup. Game code never hardcodes audio file
# paths; it requests a logical ID (SFX_*, AMB_*, MUS_*, INSTR_*) and this
# class resolves it to a variant stream from audio/audio-manifest.json,
# rotating variants so repeats stay fresh. Static + dependency-free so it
# works inside headless SceneTree test scripts (no autoload needed).
class_name AudioLibrary

const MANIFEST_PATH := "res://audio/audio-manifest.json"

static var _events: Dictionary = {}
static var _cursors: Dictionary = {}
static var _loaded := false


static func _load_manifest() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var events: Variant = parsed.get("events", {})
	if typeof(events) != TYPE_DICTIONARY:
		return
	for id: String in events:
		var entry: Variant = events[id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var raw_files: Variant = entry.get("files", [])
		if typeof(raw_files) != TYPE_ARRAY or raw_files.is_empty():
			continue
		var files: Array[String] = []
		for rel: String in raw_files:
			files.append("res://audio/" + rel)
		entry["res_files"] = files
		_events[id] = entry


static func has_event(id: String) -> bool:
	_load_manifest()
	return _events.has(id)


static func variant_count(id: String) -> int:
	_load_manifest()
	var entry: Dictionary = _events.get(id, {})
	return entry.get("res_files", []).size()


## Returns an AudioStream for the logical event, or null when unknown.
## variant < 0 rotates through available variants; >= 0 pins one.
static func stream_for(id: String, variant: int = -1) -> AudioStream:
	_load_manifest()
	var entry: Dictionary = _events.get(id, {})
	var files: Array = entry.get("res_files", [])
	if files.is_empty():
		push_warning("AudioLibrary: unknown audio event '%s'" % id)
		return null
	var index: int
	if variant >= 0 and variant < files.size():
		index = variant
	else:
		if not _cursors.has(id):
			_cursors[id] = randi() % files.size()
		index = int(_cursors[id]) % files.size()
		_cursors[id] = index + 1
	return load(files[index]) as AudioStream


## Fire-and-forget one-shot on the current scene. Returns null (and plays
## nothing) when the event is unknown or no scene tree is running.
static func play(id: String, volume_db: float = 0.0) -> AudioStreamPlayer:
	var stream := stream_for(id)
	if stream == null:
		return null
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	tree.current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return player
