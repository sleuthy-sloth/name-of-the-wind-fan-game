extends SceneTree

var _failures: int = 0

func _init() -> void:
	# Defer test execution so the SceneTree is fully ready.
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("INVENTORY_ECONOMY_TEST: START")

	_test_item_definitions_valid()

	var inventory := Inventory.new()
	_test_inventory_add_remove_count(inventory)
	_test_inventory_move(inventory)
	_test_inventory_serialization(inventory)

	_test_economy_prices(inventory)
	_test_economy_buy_sell(inventory)
	_test_economy_key_item_refusal(inventory)

	_test_hud()

	if _failures == 0:
		print("INVENTORY_ECONOMY_TEST: PASS")
		quit(0)
	else:
		print("INVENTORY_ECONOMY_TEST: FAIL (%d assertion(s) failed)" % _failures)
		quit(1)

func _test_item_definitions_valid() -> void:
	var file := FileAccess.open("res://data/items/items_act1.json", FileAccess.READ)
	_assert_true(file != null, "items JSON file opens")
	if file == null:
		return

	var raw_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw_text)
	_assert_true(parsed != null and parsed is Dictionary, "items JSON parses to Dictionary")
	if parsed == null or not (parsed is Dictionary):
		return

	var parsed_dict: Dictionary = parsed
	var items_array: Variant = parsed_dict.get("items")
	_assert_true(items_array != null and items_array is Array, "items JSON has 'items' array")
	if items_array == null or not (items_array is Array):
		return

	var valid_categories := Inventory.VALID_CATEGORIES
	var seen_ids: Dictionary = {}
	for entry: Variant in items_array:
		_assert_true(entry is Dictionary, "each item entry is a Dictionary")
		if not (entry is Dictionary):
			continue
		var entry_dict: Dictionary = entry

		var id: Variant = entry_dict.get("id")
		_assert_true(id is String, "item id is a String")
		if not (id is String):
			continue
		var id_str: String = id
		_assert_false(seen_ids.has(id_str), "item id '%s' is unique" % id_str)
		seen_ids[id_str] = true

		var category: Variant = entry_dict.get("category")
		_assert_true(category is String, "item '%s' category is a String" % id_str)
		if category is String:
			_assert_true(valid_categories.has(category), "item '%s' has known category '%s'" % [id_str, category])

		var base_price: Variant = entry_dict.get("base_price")
		_assert_true(base_price is int or base_price is float, "item '%s' base_price is numeric" % id_str)

		var key_item: Variant = entry_dict.get("key_item")
		_assert_true(key_item is bool, "item '%s' key_item is a bool" % id_str)

	# Confirm the data includes at least two key items as required.
	var key_count := 0
	for entry: Variant in items_array:
		var entry_dict: Dictionary = entry
		if entry_dict.get("key_item", false) == true:
			key_count += 1
	_assert_true(key_count >= 2, "items JSON has at least 2 key items")

func _test_inventory_add_remove_count(inventory: Inventory) -> void:
	var item_id := "item_food_travel_biscuit_v1"
	_assert_true(inventory.add_item(item_id, 3), "add_item returns true")
	_assert_eq(inventory.count_item(item_id), 3, "count_item after adding 3")
	_assert_true(inventory.has_item(item_id), "has_item returns true")

	_assert_true(inventory.remove_item(item_id, 1), "remove_item returns true")
	_assert_eq(inventory.count_item(item_id), 2, "count_item after removing 1")

	_assert_false(inventory.remove_item(item_id, 5), "remove_item fails when not enough stock")
	_assert_eq(inventory.count_item(item_id), 2, "count_item unchanged after failed remove")

func _test_inventory_move(inventory: Inventory) -> void:
	# Add a tool, then move it into another valid category to prove movement works.
	var item_id := "item_tool_lute_strings_v1"
	inventory.add_item(item_id, 2)
	var original_category := inventory.get_item_category(item_id)
	var dest_category := "quest_objects"

	_assert_true(inventory.move_item(item_id, dest_category, 1), "move_item returns true")
	_assert_eq(inventory.count_item(item_id), 2, "total count unchanged after move")
	_assert_eq(inventory.get_items_by_category(original_category).get(item_id, 0), 1, "remaining in original category")
	_assert_eq(inventory.get_items_by_category(dest_category).get(item_id, 0), 1, "present in destination category")

func _test_inventory_serialization(inventory: Inventory) -> void:
	var data := inventory.to_dict()
	_assert_true(data.has("items"), "to_dict has 'items' key")

	var fresh := Inventory.new()
	fresh.from_dict(data)
	_assert_eq(fresh.count_item("item_food_travel_biscuit_v1"), 2, "round-trip travel biscuit count")
	_assert_eq(fresh.count_item("item_tool_lute_strings_v1"), 2, "round-trip lute strings count")

func _test_economy_prices(inventory: Inventory) -> void:
	# Travel Biscuit base_price 3 -> Cheap -> buy 3, sell 2 (rounded)
	var cheap_id := "item_food_travel_biscuit_v1"
	_assert_eq(Economy.get_buy_price(cheap_id, inventory), 3, "Cheap buy price")
	_assert_eq(Economy.get_sell_price(cheap_id, inventory), 2, "Cheap sell price")
	_assert_eq(Economy.get_price_band_name(3), "Cheap", "Cheap band name")

	# Lute Strings base_price 12 -> Moderate -> buy 14, sell 7
	var moderate_id := "item_tool_lute_strings_v1"
	_assert_eq(Economy.get_buy_price(moderate_id, inventory), 14, "Moderate buy price")
	_assert_eq(Economy.get_sell_price(moderate_id, inventory), 7, "Moderate sell price")
	_assert_eq(Economy.get_price_band_name(12), "Moderate", "Moderate band name")

	# Travel Lute base_price 75 -> Expensive -> buy 113, sell 53
	var expensive_id := "item_instrument_travel_lute_v1"
	_assert_eq(Economy.get_buy_price(expensive_id, inventory), 113, "Expensive buy price")
	_assert_eq(Economy.get_sell_price(expensive_id, inventory), 53, "Expensive sell price")
	_assert_eq(Economy.get_price_band_name(75), "Expensive", "Expensive band name")

	# Mother's Brooch base_price 200 -> Critical -> buy 400, sell 160
	var critical_id := "item_quest_mothers_brooch_v1"
	_assert_eq(Economy.get_buy_price(critical_id, inventory), 400, "Critical buy price")
	_assert_eq(Economy.get_sell_price(critical_id, inventory), 160, "Critical sell price")
	_assert_eq(Economy.get_price_band_name(200), "Critical", "Critical band name")

	var formatted := Economy.format_price_band(moderate_id, inventory)
	_assert_true(formatted.contains("Lute Strings"), "format_price_band includes display name")
	_assert_true(formatted.contains("Moderate"), "format_price_band includes band name")
	_assert_true(formatted.contains("14") and formatted.contains("7"), "format_price_band includes prices")

func _test_economy_buy_sell(inventory: Inventory) -> void:
	var money_holder := _MockMoneyHolder.new()
	money_holder.money = 100

	var item_id := "item_tool_lute_strings_v1"
	var buy_result := Economy.execute_buy(item_id, inventory, money_holder)
	_assert_true(buy_result.get("success", false), "execute_buy succeeds")
	_assert_eq(money_holder.money, 86, "money deducted by buy price (100 - 14)")
	_assert_eq(inventory.count_item(item_id), 3, "inventory gains bought item")

	var sell_result := Economy.execute_sell(item_id, inventory, money_holder)
	_assert_true(sell_result.get("success", false), "execute_sell succeeds")
	_assert_eq(money_holder.money, 93, "money credited by sell price (86 + 7)")
	_assert_eq(inventory.count_item(item_id), 2, "inventory loses sold item")

func _test_economy_key_item_refusal(inventory: Inventory) -> void:
	var key_item_id := "item_quest_mothers_brooch_v1"
	inventory.add_item(key_item_id, 1)

	_assert_false(Economy.can_sell(key_item_id, inventory), "can_sell false for key item")

	var money_holder := _MockMoneyHolder.new()
	money_holder.money = 1000
	var sell_result := Economy.execute_sell(key_item_id, inventory, money_holder)
	_assert_false(sell_result.get("success", false), "execute_sell fails for key item")
	_assert_true((sell_result.get("reason", "") as String).contains("Key story items cannot be sold"), "key item refusal reason is clear")
	_assert_eq(money_holder.money, 1000, "money unchanged after refused sell")
	_assert_eq(inventory.count_item(key_item_id), 1, "key item count unchanged")

func _test_hud() -> void:
	var scene := load("res://scenes/ui/hud.tscn")
	_assert_true(scene != null, "hud scene loads")
	if scene == null:
		return

	var hud: Hud = scene.instantiate()
	root.add_child(hud)

	_assert_true(hud.money_label != null, "hud has MoneyLabel")
	_assert_true(hud.price_band_label != null, "hud has PriceBandLabel")

	hud.set_money(42)
	_assert_eq(hud.money_label.text, "Money: 42", "set_money updates label")

	var price_text := "Travel Lute - Expensive - Buy: 113 / Sell: 53"
	hud.show_price_band(price_text)
	_assert_eq(hud.price_band_label.text, price_text, "show_price_band updates label")

	hud.queue_free()

func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		push_error("ASSERT FAIL: %s (expected %s, got %s)" % [message, str(expected), str(actual)])
		_failures += 1

func _assert_true(actual: bool, message: String) -> void:
	if not actual:
		push_error("ASSERT FAIL: %s (expected true)" % message)
		_failures += 1

func _assert_false(actual: bool, message: String) -> void:
	if actual:
		push_error("ASSERT FAIL: %s (expected false)" % message)
		_failures += 1

## Minimal stand-in for GameState so Economy does not depend on the autoload.
class _MockMoneyHolder:
	var money: int = 0
