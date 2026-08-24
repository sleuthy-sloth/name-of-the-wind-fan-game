## SympathyEngine
# Pure, deterministic model for Sympathy workings.
# Implements the energy/risk formulas from GDD §8.3 and the Alar recovery
# zones from GDD §13.6. Has no autoload dependencies; callers inject the
# object that holds `alar` and `max_alar`.
class_name SympathyEngine
extends RefCounted

signal sympathy_resolved(result: Dictionary)

# Three-slot binding state.
var source: Dictionary = {}
var link: Dictionary = {}
var target: Dictionary = {}
var effect: Dictionary = {}

# Actor state.
var mastery: float = 0.0
var composure: float = 0.0
var difficulty: float = 1.0

# Seeded RNG so tests can be deterministic.
var rng: RandomNumberGenerator

func _init(p_rng: RandomNumberGenerator = null) -> void:
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()

func set_source(p_source: Dictionary) -> void:
	source = p_source

func set_link(p_link: Dictionary) -> void:
	link = p_link

func set_target(p_target: Dictionary) -> void:
	target = p_target

func set_effect(p_effect: Dictionary) -> void:
	effect = p_effect

func set_mastery(p_mastery: float) -> void:
	mastery = clampf(p_mastery, 0.0, 1.0)

func set_composure(p_composure: float) -> void:
	composure = clampf(p_composure, 0.0, 1.0)

func set_difficulty(p_difficulty: float) -> void:
	difficulty = clampf(p_difficulty, 0.1, 5.0)

func set_rng(p_rng: RandomNumberGenerator) -> void:
	rng = p_rng

# Returns true when the source/link/target/effect share a compatible energy domain.
# Nonsensical pairings are not hard-blocked; they are heavily penalized in risk.
func is_valid_binding() -> bool:
	return _domains_compatible()

# GDD §8.3 effective energy:
#   effective_energy = S × (0.5 + 0.5L) × (0.6 + 0.4M)
func compute_effective_energy() -> float:
	var S: float = source.get("energy", 0.0)
	var L: float = link.get("quality", 0.0)
	var M: float = mastery
	return S * (0.5 + 0.5 * L) * (0.6 + 0.4 * M)

# Project-specific Alar cost model derived from GDD §8.3 variables.
# Mastery and link quality reduce the mental burden of channeling the working,
# but there is always some minimum overhead (10% of the requested cost).
func compute_cost() -> float:
	var R: float = effect.get("cost", 0.0)
	var L: float = link.get("quality", 0.0)
	var M: float = mastery
	var multiplier := clampf(1.0 - 0.3 * M - 0.2 * L, 0.1, 1.0)
	return R * multiplier

# GDD §8.3 risk:
#   risk = clamp((R - effective_energy) / max(R, 1), 0, 1)
#   risk = risk × D × (1 - composure_bonus)
# We define composure_bonus as composure * 0.5 (max 50% reduction).
# Domain mismatches and insufficient target tolerance double the risk.
func compute_risk() -> float:
	var R: float = effect.get("cost", 0.0)
	var effective: float = compute_effective_energy()
	var T: float = target.get("tolerance", 0.0)
	var D: float = difficulty
	var composure_bonus: float = composure * 0.5

	var base_risk := clampf((R - effective) / maxf(R, 1.0), 0.0, 1.0)
	var risk := base_risk * D * (1.0 - composure_bonus)

	if not _domains_compatible():
		risk *= 2.0
	if T < R:
		risk *= 2.0

	return clampf(risk, 0.0, 1.0)

# Main resolution entry point.
# `alar_holder` must expose `alar` and `max_alar` properties.
# If `commit` is false, returns a preview without spending Alar or rolling.
func resolve(alar_holder: Object, commit: bool = true) -> Dictionary:
	var preview := _build_preview()
	if not commit:
		return preview

	var cost: float = preview["cost"]
	var risk: float = preview["risk"]
	var success := _roll_success(risk)
	var alar_before: float = alar_holder.alar
	var alar_spent: float = cost
	var consequence := ""

	if success:
		alar_holder.alar = clampf(alar_holder.alar - cost, 0.0, alar_holder.max_alar)
		preview["success"] = true
		preview["effect_applied"] = effect.get("payload", {}).duplicate()
		preview["message"] = "The working held; the binding carried the intended effect."
	else:
		# GDD §8.3 failure consequences: loss of Alar is the primary, immediate cost.
		# Overdrawing Alar imposes a recovery delay.
		var penalty: float = cost * 0.5
		alar_spent = cost + penalty
		alar_holder.alar = clampf(alar_holder.alar - alar_spent, 0.0, alar_holder.max_alar)
		preview["success"] = false
		preview["effect_applied"] = {}
		preview["alar_penalty"] = penalty
		preview["message"] = "Slippage: the binding broke and the energy recoiled."
		consequence = "alar_loss"
		if alar_holder.alar <= 0.0:
			consequence += "|alar_overdraw"
			preview["recovery_minutes"] = 60.0

	preview["alar_spent"] = alar_spent
	preview["alar_remaining"] = alar_holder.alar
	preview["failure_consequence"] = consequence
	sympathy_resolved.emit(preview)
	return preview

# GDD §13.6 Alar recovery zones.
#   safe_zone    = 40–100% of max Alar  -> 1.0x recovery
#   strained_zone = 20–39%             -> 0.6x recovery
#   critical_zone = 0–19%              -> 0.25x recovery
# `minutes` is abstract rest time (one game minute = one recovery unit).
static func rest_action(current_alar: float, max_alar: float, minutes: float) -> float:
	var ratio := current_alar / maxf(max_alar, 1.0)
	var rate: float
	if ratio >= 0.4:
		rate = 1.0
	elif ratio >= 0.2:
		rate = 0.6
	else:
		rate = 0.25
	return clampf(current_alar + minutes * rate, 0.0, max_alar)

func _build_preview() -> Dictionary:
	var cost := compute_cost()
	var risk := compute_risk()
	var effective := compute_effective_energy()
	return {
		"source_id": source.get("id", ""),
		"link_id": link.get("id", ""),
		"target_id": target.get("id", ""),
		"effect_id": effect.get("id", ""),
		"valid": is_valid_binding(),
		"cost": cost,
		"risk": risk,
		"effective_energy": effective,
		"success": false,
		"effect_applied": {},
		"alar_spent": 0.0,
		"alar_remaining": 0.0,
		"failure_consequence": "",
		"message": "",
	}

func _roll_success(risk: float) -> bool:
	if risk <= 0.0:
		return true
	if risk >= 1.0:
		return false
	return rng.randf() >= risk

func _domains_compatible() -> bool:
	var effect_domain: String = effect.get("domain", "")
	var source_domain: String = source.get("domain", "")
	var target_domain: String = target.get("domain", "")
	var link_domains: Variant = link.get("domains", [])

	if effect_domain.is_empty() or source_domain.is_empty() or target_domain.is_empty():
		return false
	if effect_domain != source_domain or effect_domain != target_domain:
		return false

	if link_domains is String:
		return link_domains == effect_domain
	if link_domains is Array:
		return link_domains.has(effect_domain)
	return false
