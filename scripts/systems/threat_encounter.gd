class_name ThreatEncounter
extends RefCounted

## ThreatEncounter
# Threat resolution per GDD §7.5 — this project's replacement for a combat
# system. A threat offers up to four resolutions:
#   1. flee   — pick a route; each route has an escape risk.
#   2. hide   — time your move inside the threat's attention window.
#   3. talk   — succeed when reputation or a relationship meets the bar.
#   4. sympathy — resolve through the shared SympathyEngine at real Alar cost;
#      slippage escalates pressure like any other failure.
# Failed attempts raise `pressure`; reaching `pressure_limit` ends the
# encounter in forced failure. Pure and headless-friendly: callers pass a
# holder exposing GameState-like `reputation`/`relationships`/`alar`.

const THREATS_PATH := "res://data/threats/threats_act1.json"

const TYPE_FLEE := "flee"
const TYPE_HIDE := "hide"
const TYPE_TALK := "talk"
const TYPE_SYMPATHY := "sympathy"

var def: Dictionary = {}
var pressure: int = 0

var _rng: RandomNumberGenerator
var _resolved: bool = false
var _forced_failure: bool = false

func _init(p_def: Dictionary = {}, p_rng: RandomNumberGenerator = null) -> void:
	def = p_def
	_rng = p_rng if p_rng != null else RandomNumberGenerator.new()

# --- data loading ------------------------------------------------------------

static func load_defs(path: String = THREATS_PATH) -> Array[Dictionary]:
	var defs: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_error("ThreatEncounter: threats file missing: %s" % path)
		return defs
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null or not parsed is Array:
		push_error("ThreatEncounter: %s is not a JSON array" % path)
		return defs
	for entry: Variant in parsed:
		if entry is Dictionary:
			defs.append(entry as Dictionary)
	return defs

static func find_def(threat_id: String, path: String = THREATS_PATH) -> Dictionary:
	for d in load_defs(path):
		if str(d.get("id", "")) == threat_id:
			return d
	return {}

## Structural validation for content pipelines. Returns a list of problems.
static func validate_def(d: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(d.get("id", "")).is_empty():
		errors.append("missing id")
	if str(d.get("title", "")).is_empty():
		errors.append("missing title")
	if int(d.get("pressure_limit", 0)) <= 0:
		errors.append("pressure_limit must be > 0")
	var has_resolution := false
	var flee: Dictionary = d.get("flee", {})
	if not flee.is_empty():
		has_resolution = true
		var routes: Variant = flee.get("routes", [])
		if not routes is Array or (routes as Array).is_empty():
			errors.append("flee needs routes")
	var hide: Dictionary = d.get("hide", {})
	if not hide.is_empty():
		has_resolution = true
		if float(hide.get("window_width", 0.0)) <= 0.0:
			errors.append("hide window_width must be > 0")
	if not (d.get("talk", {}) as Dictionary).is_empty():
		has_resolution = true
		var req: Dictionary = (d.get("talk", {}) as Dictionary).get("requirement", {})
		if req.is_empty():
			errors.append("talk needs a requirement")
		elif not ["reputation", "relationship", "none"].has(str(req.get("kind", ""))):
			errors.append("talk requirement kind must be reputation|relationship|none")
	if not (d.get("sympathy", {}) as Dictionary).is_empty():
		has_resolution = true
		var binding: Dictionary = d.get("sympathy", {})
		for key: String in ["source", "link", "target", "effect"]:
			if (binding.get(key, {}) as Dictionary).is_empty():
				errors.append("sympathy missing %s" % key)
	if not has_resolution:
		errors.append("threat offers no resolutions")
	return errors

# --- state -------------------------------------------------------------------

func get_title() -> String:
	return str(def.get("title", ""))

func get_intro() -> String:
	return str(def.get("intro", ""))

func pressure_limit() -> int:
	return maxi(int(def.get("pressure_limit", 3)), 1)

func is_active() -> bool:
	return not _resolved and pressure < pressure_limit()

func is_resolved() -> bool:
	return _resolved

func is_forced_failure() -> bool:
	return _forced_failure

func flee_routes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Variant in def.get("flee", {}).get("routes", []):
		if r is Dictionary:
			out.append(r as Dictionary)
	return out

func hide_window() -> Vector2:
	var hide: Dictionary = def.get("hide", {})
	return Vector2(float(hide.get("window_center", 0.5)), float(hide.get("window_width", 0.25)))

func talk_requirement() -> Dictionary:
	return def.get("talk", {}).get("requirement", {})

## True when `holder` (GameState-like) currently satisfies the talk bar.
func talk_available(holder: Object) -> bool:
	var req := talk_requirement()
	match str(req.get("kind", "none")):
		"reputation":
			var rep: Variant = holder.get("reputation") if holder != null else {}
			var value := int((rep if rep is Dictionary else {}).get(str(req.get("group", "")), 0))
			return value >= int(req.get("value", 0))
		"relationship":
			var rel: Variant = holder.get("relationships") if holder != null else {}
			var value2 := float((rel if rel is Dictionary else {}).get(str(req.get("target", "")), 0.0))
			return value2 >= float(req.get("value", 0.0))
		_:
			return true

func sympathy_binding() -> Dictionary:
	return def.get("sympathy", {})

# --- resolution --------------------------------------------------------------

## Unified attempt entry. Payloads:
##   flee     {route_index: int}
##   hide     {timing: float 0..1}
##   talk     {}
##   sympathy {}  (binding comes from def; holder pays Alar)
## Returns {type, success, resolved, forced_failure, text, pressure,
##          alar_spent?, route_id?}. Callers apply flags via flags_for().
func attempt(type: String, payload: Dictionary, holder: Object) -> Dictionary:
	var outcome := {
		"type": type,
		"success": false,
		"resolved": false,
		"forced_failure": false,
		"text": "",
		"pressure": pressure,
	}
	if not is_active():
		outcome["text"] = "The moment has already passed."
		return outcome

	match type:
		TYPE_FLEE:
			_attempt_flee(payload, outcome)
		TYPE_HIDE:
			_attempt_hide(payload, outcome)
		TYPE_TALK:
			_attempt_talk(holder, outcome)
		TYPE_SYMPATHY:
			_attempt_sympathy(holder, outcome)
		_:
			outcome["text"] = "That is no way out of trouble."

	outcome["pressure"] = pressure
	if outcome["success"]:
		_resolved = true
		outcome["resolved"] = true
	elif pressure >= pressure_limit():
		_resolved = true
		_forced_failure = true
		outcome["resolved"] = true
		outcome["forced_failure"] = true
		outcome["text"] = str(def.get("failure_text", outcome["text"]))
	return outcome

func _attempt_flee(payload: Dictionary, outcome: Dictionary) -> void:
	var routes := flee_routes()
	var index := int(payload.get("route_index", 0))
	if index < 0 or index >= routes.size():
		outcome["text"] = "There is no such way to run."
		return
	var route := routes[index]
	outcome["route_id"] = str(route.get("id", ""))
	var risk := clampf(float(route.get("risk", 0.5)), 0.0, 1.0)
	if _rng.randf() > risk:
		outcome["success"] = true
		outcome["text"] = str(route.get("success_text", def.get("flee", {}).get("success_text", "You slip away.")))
	else:
		outcome["text"] = str(route.get("fail_text", def.get("flee", {}).get("fail_text", "The route closes before you reach it.")))
		pressure += 1

func _attempt_hide(payload: Dictionary, outcome: Dictionary) -> void:
	var timing := clampf(float(payload.get("timing", -1.0)), -1.0, 1.0)
	var window := hide_window()
	var half := window.y * 0.5
	if timing >= window.x - half and timing <= window.x + half:
		outcome["success"] = true
		outcome["text"] = str(def.get("hide", {}).get("success_text", "You melt into cover and the danger passes you by."))
	else:
		outcome["text"] = str(def.get("hide", {}).get("fail_text", "You move at the wrong beat and eyes snap toward you."))
		pressure += 1

func _attempt_talk(holder: Object, outcome: Dictionary) -> void:
	if talk_available(holder):
		outcome["success"] = true
		outcome["text"] = str(def.get("talk", {}).get("success_text", "Words do what fists cannot."))
	else:
		outcome["text"] = str(def.get("talk", {}).get("fail_text", "Your words land on deaf ears and make things worse."))
		pressure += 1

func _attempt_sympathy(holder: Object, outcome: Dictionary) -> void:
	var binding := sympathy_binding()
	if binding.is_empty():
		outcome["text"] = "No working comes to mind."
		return
	var result := _build_sympathy_engine().resolve(holder, true)
	outcome["alar_spent"] = result.get("alar_spent", 0.0)
	if result.get("success", false):
		outcome["success"] = true
		outcome["text"] = str(binding.get("success_text", result.get("message", "")))
	else:
		outcome["text"] = str(binding.get("fail_text", result.get("message", "Slippage: the binding breaks under pressure.")))
		pressure += 1

## Pre-commit preview of the sympathy resolution at the current pressure.
func sympathy_preview() -> Dictionary:
	var binding := sympathy_binding()
	if binding.is_empty():
		return {}
	var engine := _build_sympathy_engine()
	var p := engine.resolve(null, false)
	p["title"] = str(binding.get("effect", {}).get("label", "Sympathy"))
	return p

func _build_sympathy_engine() -> SympathyEngine:
	var binding := sympathy_binding()
	var engine := SympathyEngine.new(_rng)
	engine.set_source(binding.get("source", {}))
	engine.set_link(binding.get("link", {}))
	engine.set_target(binding.get("target", {}))
	engine.set_effect(binding.get("effect", {}))
	# Pressure frays concentration: composure drops as threats escalate.
	engine.set_mastery(float(binding.get("mastery", 0.35)))
	engine.set_composure(clampf(float(binding.get("composure", 0.4)) - 0.1 * float(pressure), 0.0, 1.0))
	engine.set_difficulty(float(binding.get("difficulty", 1.2)))
	return engine

# --- flags -------------------------------------------------------------------

## Flags a caller should apply for this encounter's final state.
func flags_for(outcome: Dictionary) -> Array[String]:
	var flags: Array[String] = []
	var flag_map: Dictionary = def.get("flags", {})
	if not outcome.get("resolved", false):
		return flags
	if outcome.get("success", false):
		var success_flag := str(flag_map.get("success_flag", ""))
		if not success_flag.is_empty():
			flags.append(success_flag)
	else:
		var failure_flag := str(flag_map.get("failure_flag", ""))
		if not failure_flag.is_empty():
			flags.append(failure_flag)
	return flags
