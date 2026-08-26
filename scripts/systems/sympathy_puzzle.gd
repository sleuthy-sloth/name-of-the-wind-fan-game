class_name SympathyPuzzle
extends RefCounted

## SympathyPuzzle
# Out-of-combat sympathy working (GDD §8 / §7.5 resolution 4 outside threats).
# A puzzle definition pins link, target, and effect while offering the player
# a choice of energy sources; picking a weaker source raises Alar cost and
# risk through the shared SympathyEngine formulas. Pure and deterministic:
# callers inject an alar holder (anything with `alar`/`max_alar`) and an RNG.

const WORKINGS_PATH := "res://data/workings/workings_act1.json"

var def: Dictionary = {}
var engine: SympathyEngine
var _selected_source_index: int = -1

func _init(p_def: Dictionary = {}, p_rng: RandomNumberGenerator = null) -> void:
	def = p_def
	engine = SympathyEngine.new(p_rng)
	set_mastery(def.get("mastery", 0.3))
	set_composure(def.get("composure", 0.3))
	select_source(0)

# --- data loading ------------------------------------------------------------

static func load_defs(path: String = WORKINGS_PATH) -> Array[Dictionary]:
	var defs: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_error("SympathyPuzzle: workings file missing: %s" % path)
		return defs
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null or not parsed is Array:
		push_error("SympathyPuzzle: %s is not a JSON array" % path)
		return defs
	for entry: Variant in parsed:
		if entry is Dictionary:
			defs.append(entry as Dictionary)
	return defs

static func find_def(working_id: String, path: String = WORKINGS_PATH) -> Dictionary:
	for d in load_defs(path):
		if str(d.get("id", "")) == working_id:
			return d
	return {}

## Structural validation for content pipelines. Returns a list of problems.
static func validate_def(d: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(d.get("id", "")).is_empty():
		errors.append("missing id")
	if str(d.get("title", "")).is_empty():
		errors.append("missing title")
	if str(d.get("prompt", "")).is_empty():
		errors.append("missing prompt")
	var sources: Variant = d.get("sources", [])
	if not sources is Array or (sources as Array).is_empty():
		errors.append("needs at least one source")
	else:
		for s: Variant in sources:
			if not s is Dictionary or str((s as Dictionary).get("id", "")).is_empty():
				errors.append("malformed source entry")
				break
	for key: String in ["link", "target", "effect"]:
		var part: Dictionary = d.get(key, {})
		if part.is_empty() or str(part.get("id", "")).is_empty():
			errors.append("missing %s id" % key)
	var effect: Dictionary = d.get("effect", {})
	var domain := str(effect.get("domain", ""))
	if domain.is_empty():
		errors.append("effect needs a domain")
	else:
		var link: Dictionary = d.get("link", {})
		var link_domains: Variant = link.get("domains", [])
		if link_domains is Array:
			if not (link_domains as Array).has(domain):
				errors.append("link does not carry effect domain")
		elif str(link_domains) != domain and str(link.get("domain", "")) != domain:
			errors.append("link does not carry effect domain")
	if str(d.get("world_effect", "")).is_empty():
		errors.append("missing world_effect (open_door|move_obstacle)")
	if str(d.get("on_success_flag", "")).is_empty():
		errors.append("missing on_success_flag")
	return errors

# --- configuration -----------------------------------------------------------

func set_mastery(value: float) -> void:
	engine.set_mastery(value)

func set_composure(value: float) -> void:
	engine.set_composure(value)

func set_difficulty(value: float) -> void:
	engine.set_difficulty(value)

func sources() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Variant in def.get("sources", []):
		if s is Dictionary:
			out.append(s as Dictionary)
	return out

func select_source(index: int) -> void:
	var pool := sources()
	if pool.is_empty():
		_selected_source_index = -1
		return
	_selected_source_index = clampi(index, 0, pool.size() - 1)
	_rebuild_binding()

func selected_source_index() -> int:
	return _selected_source_index

func _rebuild_binding() -> void:
	engine.set_source(_dict_at(sources(), _selected_source_index))
	engine.set_link(_as_dict(def.get("link", {})))
	engine.set_target(_as_dict(def.get("target", {})))
	engine.set_effect(_as_dict(def.get("effect", {})))

# --- resolution --------------------------------------------------------------

## Pre-commit preview: cost/risk/validity without spending anything.
func preview() -> Dictionary:
	var p := engine.resolve(null, false)
	p["working_id"] = str(def.get("id", ""))
	p["title"] = str(def.get("title", ""))
	return p

## Commits the working against `alar_holder`. On success the result carries the
## world payload so callers can apply it: world_effect, on_success_flag,
## success_text. Never touches GameState directly — nodes own that.
func commit(alar_holder: Object) -> Dictionary:
	var result := engine.resolve(alar_holder, true)
	result["working_id"] = str(def.get("id", ""))
	if result.get("success", false):
		result["world_effect"] = str(def.get("world_effect", ""))
		result["flag"] = str(def.get("on_success_flag", ""))
		result["message"] = str(def.get("success_text", result["message"]))
	return result

func _dict_at(pool: Array[Dictionary], index: int) -> Dictionary:
	return _as_dict(pool[index]) if index >= 0 and index < pool.size() else {}

static func _as_dict(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
