## Economy
# Price-band logic and transaction execution for "The Name of the Wind" fan game.
# This class is intentionally decoupled from GameState: callers pass an Inventory
# and a money holder (production code typically passes the GameState autoload).
class_name Economy
extends RefCounted

enum PriceBand {
	CHEAP,
	MODERATE,
	EXPENSIVE,
	CRITICAL,
}

const BAND_NAMES := {
	PriceBand.CHEAP: "Cheap",
	PriceBand.MODERATE: "Moderate",
	PriceBand.EXPENSIVE: "Expensive",
	PriceBand.CRITICAL: "Critical",
}

# Buy factors are applied to base_price when a vendor sells to the player.
# Sell factors are applied when the player sells to a vendor.
# These map the qualitative bands in GDD §13.2 to legible integer prices.
const BUY_FACTORS := {
	PriceBand.CHEAP: 1.0,
	PriceBand.MODERATE: 1.2,
	PriceBand.EXPENSIVE: 1.5,
	PriceBand.CRITICAL: 2.0,
}

const SELL_FACTORS := {
	PriceBand.CHEAP: 0.5,
	PriceBand.MODERATE: 0.6,
	PriceBand.EXPENSIVE: 0.7,
	PriceBand.CRITICAL: 0.8,
}

## Returns the PriceBand enum value for a given base price.
static func get_price_band(base_price: int) -> PriceBand:
	if base_price < 0:
		return PriceBand.CHEAP
	if base_price < 10:
		return PriceBand.CHEAP
	if base_price < 50:
		return PriceBand.MODERATE
	if base_price < 200:
		return PriceBand.EXPENSIVE
	return PriceBand.CRITICAL

## Returns the human-readable band label for a base price.
static func get_price_band_name(base_price: int) -> String:
	return BAND_NAMES[get_price_band(base_price)]

## Returns the vendor sell price (what the player pays) for an item.
static func get_buy_price(item_id: String, inventory: Inventory) -> int:
	var def := inventory.get_definition(item_id)
	var base_price: int = _int_from_def(def, "base_price", 0)
	return _apply_factor(base_price, BUY_FACTORS[get_price_band(base_price)])

## Returns the vendor buy price (what the player receives) for an item.
static func get_sell_price(item_id: String, inventory: Inventory) -> int:
	var def := inventory.get_definition(item_id)
	var base_price: int = _int_from_def(def, "base_price", 0)
	return _apply_factor(base_price, SELL_FACTORS[get_price_band(base_price)])

## Builds the pre-confirmation display line: "Item Name - Moderate - Buy: 15 / Sell: 8".
static func format_price_band(item_id: String, inventory: Inventory) -> String:
	var def := inventory.get_definition(item_id)
	var display_name: String = _string_from_def(def, "display_name", item_id)
	var base_price: int = _int_from_def(def, "base_price", 0)
	var band_name := get_price_band_name(base_price)
	var buy := get_buy_price(item_id, inventory)
	var sell := get_sell_price(item_id, inventory)
	return "%s - %s - Buy: %d / Sell: %d" % [display_name, band_name, buy, sell]

## Returns false for key items, which must never be accidentally sold.
static func can_sell(item_id: String, inventory: Inventory) -> bool:
	return not inventory.is_key_item(item_id)

## Attempts to buy one of item_id. money_holder must have a writable `money` property.
## Returns { "success": bool, "reason": String }.
static func execute_buy(item_id: String, inventory: Inventory, money_holder: Object) -> Dictionary:
	if not inventory.has_definition(item_id):
		return {"success": false, "reason": "Unknown item."}

	var price := get_buy_price(item_id, inventory)
	if not _has_money_property(money_holder):
		return {"success": false, "reason": "Money holder is missing a money property."}

	var available: int = money_holder.money
	if available < price:
		return {"success": false, "reason": "Not enough money (%d needed, %d available)." % [price, available]}

	if not inventory.add_item(item_id, 1):
		return {"success": false, "reason": "Could not add item to inventory."}

	money_holder.money = available - price
	return {"success": true, "reason": "Purchased %s for %d." % [item_id, price]}

## Attempts to sell one of item_id. money_holder must have a writable `money` property.
## Returns { "success": bool, "reason": String }.
static func execute_sell(item_id: String, inventory: Inventory, money_holder: Object) -> Dictionary:
	if not inventory.has_definition(item_id):
		return {"success": false, "reason": "Unknown item."}

	if not can_sell(item_id, inventory):
		return {"success": false, "reason": "Key story items cannot be sold."}

	if inventory.count_item(item_id) <= 0:
		return {"success": false, "reason": "Item not in inventory."}

	if not _has_money_property(money_holder):
		return {"success": false, "reason": "Money holder is missing a money property."}

	var price := get_sell_price(item_id, inventory)
	if not inventory.remove_item(item_id, 1):
		return {"success": false, "reason": "Could not remove item from inventory."}

	money_holder.money = money_holder.money + price
	return {"success": true, "reason": "Sold %s for %d." % [item_id, price]}

static func _apply_factor(base_price: int, factor: float) -> int:
	return int(round(base_price * factor))

static func _int_from_def(def: Dictionary, key: String, default_value: int) -> int:
	var value: Variant = def.get(key)
	if value is int:
		return value
	if value is float:
		return int(value)
	return default_value

static func _string_from_def(def: Dictionary, key: String, default_value: String) -> String:
	var value: Variant = def.get(key)
	if value is String:
		return value
	return default_value

static func _has_money_property(holder: Object) -> bool:
	if holder == null:
		return false
	return holder.get_property_list().any(func(p: Dictionary) -> bool:
		return p.get("name", "") == "money" and p.get("usage", 0) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0
	)
