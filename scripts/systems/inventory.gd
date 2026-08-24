## Inventory
# Data-driven inventory manager for "The Name of the Wind" fan game.
# Items are defined in data/items/items_act1.json and referenced by stable id.
# Supports stacking per category, category movement, and full serialization.
class_name Inventory
extends RefCounted

const ITEMS_PATH := "res://data/items/items_act1.json"
const VALID_CATEGORIES := [
	"currency",
	"food_and_warmth",
	"tools_and_materials",
	"documents_and_clues",
	"crafted_items",
	"instruments_and_performance_aids",
	"quest_objects",
]

var _definitions: Dictionary = {}     # item_id -> definition Dictionary
var _items: Dictionary = {}           # category -> { item_id -> count }

func _init() -> void:
	_load_definitions()
	for category in VALID_CATEGORIES:
		_items[category] = {}

func _load_definitions() -> void:
	var file := FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if file == null:
		push_error("Inventory: failed to open item definitions at %s" % ITEMS_PATH)
		return

	var raw_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw_text)
	if parsed == null or not (parsed is Dictionary):
		push_error("Inventory: item definitions JSON is malformed")
		return

	var parsed_dict: Dictionary = parsed
	var items_array: Variant = parsed_dict.get("items")
	if items_array == null or not (items_array is Array):
		push_error("Inventory: item definitions missing 'items' array")
		return

	for entry: Variant in items_array:
		if not (entry is Dictionary):
			continue
		var entry_dict: Dictionary = entry
		var id: Variant = entry_dict.get("id")
		if id == null or not (id is String):
			continue
		var id_str: String = id
		_definitions[id_str] = entry_dict

## Returns the full definition dictionary for an item id, or an empty dictionary if unknown.
func get_definition(item_id: String) -> Dictionary:
	return _definitions.get(item_id, {})

## Returns true if the item id is known in the item database.
func has_definition(item_id: String) -> bool:
	return _definitions.has(item_id)

## Returns the item's declared category, or an empty string if unknown.
func get_item_category(item_id: String) -> String:
	var def := get_definition(item_id)
	var category: Variant = def.get("category")
	if category is String:
		return category
	return ""

## Returns true if the item is marked as a key (story) item.
func is_key_item(item_id: String) -> bool:
	var def := get_definition(item_id)
	var key: Variant = def.get("key_item")
	if key is bool:
		return key
	return false

## Adds quantity of item_id to its declared category. Returns true on success.
## Adding an unknown item fails loudly and returns false.
func add_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	if not has_definition(item_id):
		push_error("Inventory: cannot add unknown item '%s'" % item_id)
		return false

	var category := get_item_category(item_id)
	if category.is_empty() or not _items.has(category):
		push_error("Inventory: item '%s' has invalid category '%s'" % [item_id, category])
		return false

	var category_items: Dictionary = _items[category]
	var current: int = category_items.get(item_id, 0)
	category_items[item_id] = current + quantity
	return true

## Removes up to quantity of item_id from whichever category holds it.
## Returns true if the full quantity was removed.
func remove_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false

	var category := get_item_category(item_id)
	if not category.is_empty() and _items.has(category):
		var category_items: Dictionary = _items[category]
		var current: int = category_items.get(item_id, 0)
		if current >= quantity:
			var remaining: int = current - quantity
			if remaining > 0:
				category_items[item_id] = remaining
			else:
				category_items.erase(item_id)
			return true

	return false

## Moves quantity of item_id into to_category. The item must already be held;
## the destination must be a valid category. Returns true on success.
func move_item(item_id: String, to_category: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	if not VALID_CATEGORIES.has(to_category):
		push_error("Inventory: cannot move to invalid category '%s'" % to_category)
		return false
	if count_item(item_id) < quantity:
		return false

	var from_category := get_item_category(item_id)
	if from_category == to_category:
		return true

	# Remove from the category that actually holds the stack.
	var removed := remove_item(item_id, quantity)
	if not removed:
		return false

	var dest_items: Dictionary = _items[to_category]
	var current: int = dest_items.get(item_id, 0)
	dest_items[item_id] = current + quantity
	return true

## Returns the total quantity of item_id held across all categories.
func count_item(item_id: String) -> int:
	var total := 0
	for category_items: Dictionary in _items.values():
		total += category_items.get(item_id, 0)
	return total

## Returns whether at least one of item_id is held.
func has_item(item_id: String) -> bool:
	return count_item(item_id) > 0

## Returns a copy of { item_id -> count } for the given category.
func get_items_by_category(category: String) -> Dictionary:
	if _items.has(category):
		return _items[category].duplicate()
	return {}

## Returns all categories currently holding at least one item.
func get_occupied_categories() -> Array:
	var occupied: Array = []
	for category: String in _items.keys():
		var category_items: Dictionary = _items[category]
		if not category_items.is_empty():
			occupied.append(category)
	return occupied

## Serializes the inventory to a Dictionary suitable for save/load.
## Shape: { "items": { category: { item_id: count } } }
func to_dict() -> Dictionary:
	var serialized := {}
	for category: String in _items.keys():
		var category_items: Dictionary = _items[category]
		if not category_items.is_empty():
			serialized[category] = category_items.duplicate()
	return {"items": serialized}

## Restores the inventory from a previously serialized dictionary.
func from_dict(d: Dictionary) -> void:
	for category: String in VALID_CATEGORIES:
		_items[category] = {}

	var stored_items: Variant = d.get("items")
	if stored_items == null or not (stored_items is Dictionary):
		return

	var stored_dict: Dictionary = stored_items
	for category: String in stored_dict.keys():
		if not VALID_CATEGORIES.has(category):
			continue
		var category_data: Variant = stored_dict[category]
		if not (category_data is Dictionary):
			continue
		var category_items: Dictionary = category_data
		for item_id: String in category_items.keys():
			var count_value: Variant = category_items[item_id]
			if count_value is int and count_value > 0:
				_items[category][item_id] = count_value

## Returns a duplicate of all loaded item definitions keyed by id.
## Useful for validation, UI lists, and tests.
func get_all_definitions() -> Dictionary:
	return _definitions.duplicate()
