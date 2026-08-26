extends Node

## ChroniclerJournal
# Auto-written record of Kvothe's story, narrated in Chronicler's voice.
# Systems emit events (puzzle solved, threat resolved, scene visited, etc.);
# this singleton attaches headings/bodies via small templates and appends to
# a persistent entry list. Participates in the save system. Tests can call
# `add_event(...)` directly to drive the UI without triggering gameplay.
# Autoload singleton — no class_name so it doesn't shadow the autoload name.

signal entry_added(entry: Dictionary)

const SCENE_REGISTRY_PATH := "res://data/journal/scene_registry.json"
const SAVE_ID := "chronicler_journal"
const SEEN_MAX := 256

var _entries: Array[Dictionary] = []
var _seen_keys: Array[String] = []
## Entry templates keyed by event kind. `{heading}`, `{body}`, and per-event
## slots are filled at add_event() time. Cheap so journal flavor can be tuned
## without touching code.
var _templates: Dictionary = {
	"waystone_opening_seen": {
		"heading": "The Waystone Inn",
		"body": "An inn called the Waystone at the meeting of two roads. The innkeeper's name is Kote. He polishes a counter that wants no polishing, and watches the road like a man watching for someone he owes money to.",
	},
	"intro_opening_seen": {
		"heading": "The frame begins",
		"body": "I begin this record at the inn, before the boy becomes the man the stories already know.",
	},
	"caravan_arrival": {
		"heading": "On the road",
		"body": "Tonight the wagons roll out at first light, and the boy does not know what it will cost him.",
	},
	"camp_established": {
		"heading": "First camp",
		"body": "He makes his first camp under the name of Edema Ruh, and learns that belonging has duties.",
	},
	"abenthy_lesson": {
		"heading": "Lesson with Abenthy",
		"body": "Today Abenthy taught me how to put on the tinker man's cap. The alar of a mind can hold a working, so long as it does not falter.",
	},
	"lute_performance": {
		"heading": "The lute",
		"body": "The lute was given, the lute was played. Music, it turns out, is an action, not a decoration.",
	},
	"sympathy_lesson": {
		"heading": "First working",
		"body": "Sympathy is not a trick. It is a contract with the world: source, link, target, and the alar to pay for keeping them bound.",
	},
	"sympathy_experiment": {
		"heading": "Controlled experiment",
		"body": "The bench kept faith tonight, and the light answered in colour.",
	},
	"threat_resolved": {
		"heading": "{title}",
		"body": "There was a problem at the {title}. I {verb} it.",
	},
	"threat_failed": {
		"heading": "{title} — by force",
		"body": "There was a problem at the {title}. It did not go well.",
	},
	"puzzle_solved": {
		"heading": "{working_title}",
		"body": "Today I learned something useful: how to {verb} with a working.",
	},
	"puzzle_practiced": {
		"heading": "{working_title} — again",
		"body": "Same lesson, different day. The cost was different this time.",
	},
	"visit_first": {
		"heading": "{scene_name}",
		"body": "I {first_or_again} arrived at {scene_name}.",
	},
	"visit_again": {
		"heading": "{scene_name} — return",
		"body": "I had been to {scene_name} before. It looked the same.",
	},
	"beat_caravan": {"heading":"A road begins","body":"The road bends east. The wagons keep their pace."},
	"beat_camp": {"heading":"Camp","body":"The troupe makes camp, and the boy learns to set a kettle."},
	"beat_abenthy": {"heading":"Tinker-man","body":"Abenthy shows the boy how to split a sympathy."},
	"beat_lute": {"heading":"First lute","body":"The lute is real, and the stage is real, and the audience pays."},
	"beat_explore": {"heading":"A small investigation","body":"There is more to learn than tomorrow will let in."},
	"beat_sympathy": {"heading":"The bench","body":"Three slots, three rules. The mind does the rest."},
	"beat_experiment": {"heading":"A lighting test","body":"Light bends under alar. It bends back, too."},
	"beat_evening": {"heading":"Evening","body":"A small crowd, a small stage, a small pay."},
	"beat_attack": {"heading":"The Chandrian","body":"The fire came. The music stopped. The night that began at supper ended before morning."},
	"beat_escape": {"heading":"Afterward","body":"He walked out of the smoke alone."},
	"beat_solo_survive": {"heading":"Fire against the dark","body":"Tonight I kept a fire alive by myself. It is not a thing I will forget."},
	"beat_tarbean_road": {"heading":"The road to Tarbean","body":"Three days of walking and one of looking. The city does not care that I am still breathing."},
}
var _scene_registry: Dictionary = {}
var _puzzle_verbs: Dictionary = {
	"working_jammed_wagon_gate": "loosen a rusted pin",
	"working_swollen_hatch_latch": "draw a swollen latch with heat",
	"working_split_boulder": "fire-set a boulder out of the road",
	"working_light_the_lamp": "kindle a cold lamp",
	"working_friction_fire": "kindle a fire with friction alone",
}

## Godot 4 Dictionary.get() takes one arg; helper for "default on miss".
static func get_or(d: Dictionary, key: String, default_value: Variant) -> Variant:
	return default_value if not d.has(key) else d[key]

func _ready() -> void:
	add_to_group("save_contributors")
	_load_scene_registry()

func save_state_id() -> String:
	return SAVE_ID

func _load_scene_registry() -> void:
	if not FileAccess.file_exists(SCENE_REGISTRY_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENE_REGISTRY_PATH))
	if parsed is Dictionary:
		var raw_scenes: Variant = get_or(parsed as Dictionary, "scenes", [])
		for entry: Variant in raw_scenes:
			if entry is Dictionary:
				var id_str := str(get_or(entry as Dictionary, "id", ""))
				_scene_registry[id_str] = entry as Dictionary

func scene_entry(id: String) -> Dictionary:
	return get_or(_scene_registry, id, {})

# --- API ----------------------------------------------------------------------

## Low-level append (no template lookup). Provide heading + body directly.
func add_entry(heading: String, body: String, kind := "event") -> void:
	var id := _make_id(heading, kind)
	if _seen_keys.has(id):
		return
	var entry := {
		"id": id,
		"heading": heading,
		"body": body,
		"kind": kind,
		"timestamp": Time.get_unix_time_from_system(),
		"act": _act(),
		"day": _day(),
	}
	_seen_keys.append(id)
	if _seen_keys.size() > SEEN_MAX:
		_seen_keys = _seen_keys.slice(_seen_keys.size() - SEEN_MAX, _seen_keys.size())
	_entries.append(entry)
	entry_added.emit(entry)

## High-level event ingest: looks up the template and fills slots.
func add_event(kind: String, slots: Dictionary = {}) -> void:
	var template: Dictionary = get_or(_templates, kind, {})
	if (template as Dictionary).is_empty():
		add_entry(kind, "")
		return
	var heading := str(get_or(template as Dictionary, "heading", kind))
	var body := str(get_or(template as Dictionary, "body", ""))
	for key: String in slots:
		var placeholder := "{" + key + "}"
		var value := str(slots[key])
		heading = heading.replace(placeholder, value)
		body = body.replace(placeholder, value)
	add_entry(heading, body, kind)

## Idempotent counterpart for beat-advance events.
func note_beat(beat_id: String) -> void:
	if _templates.has(beat_id):
		add_event(beat_id)
	else:
		add_entry(beat_id, "")

func note_visit(scene_id: String) -> void:
	var data: Dictionary = scene_entry(scene_id)
	var name := str(get_or(data, "display_name", scene_id))
	if not _has_visited(name):
		add_event("visit_first", {"scene_name": name})
	else:
		add_event("visit_again", {"scene_name": name, "first_or_again": "again"})

func _has_visited(name: String) -> bool:
	for entry in _entries:
		var heading := str(get_or(entry, "heading", ""))
		var kind := str(get_or(entry, "kind", ""))
		if heading == name and (kind == "visit_first" or kind == "visit_again"):
			return true
		if heading == name + " — return":
			return true
	return false

func note_threat(threat: ThreatEncounter, outcome: Dictionary) -> void:
	var title: String = threat.get_title()
	var verb := _threat_verb(outcome)
	if bool(get_or(outcome, "resolved", false)) and bool(get_or(outcome, "success", false)):
		add_event("threat_resolved", {"title": title, "verb": verb})
	elif bool(get_or(outcome, "forced_failure", false)):
		add_event("threat_failed", {"title": title, "verb": verb})

func note_puzzle(working_id: String, working_title: String, success: bool) -> void:
	if not success:
		return
	var prefix := "puzzle_solved"
	if _seen_keys.has(_make_id(working_title, prefix)):
		prefix = "puzzle_practiced"
	add_event(prefix, {
		"working_title": working_title,
		"verb": str(get_or(_puzzle_verbs, working_id, "solve a small working")),
	})

func list_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)

func entry_count() -> int:
	return _entries.size()

func clear() -> void:
	_entries.clear()
	_seen_keys.clear()

# --- save / load --------------------------------------------------------------

func collect_save_state() -> Dictionary:
	return {
		"entries": _entries.duplicate(true),
		"seen_keys": _seen_keys.duplicate(),
	}

func apply_save_state(state: Dictionary) -> void:
	_entries.clear()
	for entry: Variant in get_or(state, "entries", []):
		if entry is Dictionary:
			_entries.append(entry as Dictionary)
	_seen_keys.clear()
	for k: Variant in get_or(state, "seen_keys", []):
		_seen_keys.append(str(k))

func _act() -> int:
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		var v = gs.get("act")
		return int(v) if v != null else 1
	return 1

func _day() -> int:
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		var v = gs.get("day")
		return int(v) if v != null else 1
	return 1

func _threat_verb(outcome: Dictionary) -> String:
	if bool(get_or(outcome, "success", false)):
		return "talked / fled / hid / worked my way past"
	if bool(get_or(outcome, "forced_failure", false)):
		return "got through it the hard way"
	return "dealt with it"

func _make_id(heading: String, kind: String) -> String:
	return kind + "::" + heading
