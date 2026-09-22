extends GutTest
## Inventar als Raster, Gold und Verkaufen (AP4).

var inv: Inventory


func before_each() -> void:
	inv = add_child_autofree(Inventory.new())
	inv.width = 4
	inv.height = 3


func _item(size: Vector2i, rarity: Enums.Rarity = Enums.Rarity.NORMAL) -> ItemInstance:
	var base := ItemBase.new()
	base.grid_size = size
	base.display_name = "Testding"
	var item := ItemInstance.new()
	item.base = base
	item.rarity = rarity
	item.item_level = 5
	return item


func test_add_fills_grid_from_top_left() -> void:
	var a := _item(Vector2i(2, 3))
	var b := _item(Vector2i(1, 1))
	assert_true(inv.add_item(a))
	assert_true(inv.add_item(b))
	assert_eq(inv.get_position_of(a), Vector2i(0, 0))
	assert_eq(inv.get_position_of(b), Vector2i(2, 0))
	assert_eq(inv.get_item_at(Vector2i(1, 2)), a, "Gegenstand belegt alle Zellen")
	assert_eq(inv.get_item_count(), 2)


func test_full_inventory_rejects() -> void:
	assert_true(inv.add_item(_item(Vector2i(2, 3))))
	assert_true(inv.add_item(_item(Vector2i(2, 3))))
	var extra := _item(Vector2i(1, 1))
	assert_false(inv.has_space_for(extra))
	assert_false(inv.add_item(extra))
	assert_false(inv.has_item(extra))


func test_place_move_and_remove() -> void:
	var a := _item(Vector2i(2, 2))
	assert_false(inv.place_item(a, Vector2i(3, 0)), "ragt über den Rand")
	assert_true(inv.place_item(a, Vector2i(1, 1)))
	var b := _item(Vector2i(1, 1))
	assert_false(inv.place_item(b, Vector2i(2, 2)), "Zelle belegt")
	assert_true(inv.move_item(a, Vector2i(2, 1)), "Verschieben darf sich selbst überlappen")
	assert_eq(inv.get_item_at(Vector2i(1, 1)), null)
	assert_true(inv.remove_item(a))
	assert_eq(inv.get_item_at(Vector2i(3, 2)), null)
	assert_false(inv.remove_item(a))


func test_same_item_cannot_be_added_twice() -> void:
	var a := _item(Vector2i(1, 1))
	assert_true(inv.add_item(a))
	assert_false(inv.add_item(a))


func test_pick_up_emits_signal() -> void:
	watch_signals(EventBus)
	var a := _item(Vector2i(1, 1))
	assert_true(inv.pick_up(a))
	assert_signal_emitted_with_parameters(EventBus, "loot_picked_up", [a])


func test_gold_add_spend_and_signal() -> void:
	watch_signals(EventBus)
	inv.add_gold(50)
	assert_signal_emitted_with_parameters(EventBus, "gold_changed", [50, 50])
	assert_false(inv.spend_gold(80))
	assert_eq(inv.gold, 50)
	assert_true(inv.spend_gold(30))
	assert_signal_emitted_with_parameters(EventBus, "gold_changed", [20, -30])
	assert_eq(inv.gold, 20)


func test_sell_item_gives_gold() -> void:
	var item := _item(Vector2i(1, 1), Enums.Rarity.RARE)
	inv.add_item(item)
	var value := inv.sell_item(item)
	assert_eq(value, ItemValue.sell_value(item))
	assert_eq(inv.gold, value)
	assert_false(inv.has_item(item))
	assert_eq(inv.sell_item(item), 0, "nicht zweimal verkaufen")


func test_find_on_owner() -> void:
	var owner_node: Node3D = add_child_autofree(Node3D.new())
	var child := Inventory.new()
	owner_node.add_child(child)
	assert_eq(Inventory.find_on(owner_node), child)
	assert_null(Inventory.find_on(null))
