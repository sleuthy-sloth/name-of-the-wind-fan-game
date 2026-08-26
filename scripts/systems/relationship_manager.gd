extends Node

## RelationshipManager
# Typed API + signals over GameState.relationships (character id -> float)
# and GameState.reputation (group -> int), per GDD Phase 2.
# Values persist through existing save plumbing; this manager adds clamping,
# tier queries, and change notifications.

signal relationship_changed(character_id: String, value: float, delta: float)
signal reputation_changed(group: String, value: int, delta: int)

const MIN_RELATIONSHIP := -100.0
const MAX_RELATIONSHIP := 100.0

## Relationship tiers used by dialogue conditions and UI color coding.
static func relationship_tier(value: float) -> String:
	if value <= -50.0:
		return "hostile"
	if value < 0.0:
		return "cold"
	if value < 25.0:
		return "neutral"
	if value < 60.0:
		return "warm"
	return "close"

func _gs() -> Node:
	return get_node_or_null("/root/GameState")

func get_relationship(character_id: String) -> float:
	var gs := _gs()
	if gs == null:
		return 0.0
	return float(gs.relationships.get(character_id, 0.0))

func adjust_relationship(character_id: String, delta: float) -> float:
	var gs := _gs()
	if gs == null:
		return 0.0
	var current := get_relationship(character_id)
	var next := clampf(current + delta, MIN_RELATIONSHIP, MAX_RELATIONSHIP)
	gs.relationships[character_id] = next
	if not is_equal_approx(current, next):
		relationship_changed.emit(character_id, next, next - current)
		var qm := get_node_or_null("/root/QuestManager")
		if qm != null:
			qm.call("notify_relationship", character_id)
	return next

func set_relationship(character_id: String, value: float) -> float:
	var current := get_relationship(character_id)
	return adjust_relationship(character_id, value - current)

func tier_of(character_id: String) -> String:
	return relationship_tier(get_relationship(character_id))

func meets_threshold(character_id: String, minimum: float) -> bool:
	return get_relationship(character_id) >= minimum

# --- reputation -------------------------------------------------------------

func get_reputation(group: String) -> int:
	var gs := _gs()
	if gs == null:
		return 0
	return int(gs.reputation.get(group, 0))

func adjust_reputation(group: String, delta: int) -> int:
	var gs := _gs()
	if gs == null:
		return 0
	var current := get_reputation(group)
	gs.reputation[group] = current + delta
	reputation_changed.emit(group, current + delta, delta)
	return current + delta

## Standing label for a reputation group relative to thresholds used by GDD §9.
func reputation_standing(group: String) -> String:
	var v := get_reputation(group)
	if v <= -30:
		return "shunned"
	if v < 0:
		return "distrusted"
	if v < 20:
		return "unknown"
	if v < 50:
		return "respected"
	return "celebrated"
