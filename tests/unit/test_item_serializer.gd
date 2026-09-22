extends GutTest
## Speichern und Laden von Gegenständen, Inventar und Ausrüstung über JSON (für AP9).

var db: ItemDatabase
var gen: ItemGenerator


func before_all() -> void:
	db = ItemDatabase.get_default()
	gen = ItemGenerator.new(db)


func _roundtrip(item: ItemInstance) -> ItemInstance:
	var json := JSON.stringify(ItemSerializer.item_to_dict(item))
	return ItemSerializer.item_from_dict(JSON.parse_string(json), db)


func _assert_same(a: ItemInstance, b: ItemInstance) -> void:
	assert_not_null(b)
	assert_eq(b.uid, a.uid)
	assert_eq(b.base, a.base)
	assert_eq(b.rarity, a.rarity)
	assert_eq(b.item_level, a.item_level)
	assert_eq(b.aspect, a.aspect)
	assert_eq(b.unique, a.unique)
	assert_eq(b.get_display_name(), a.get_display_name())
	assert_eq(b.get_stats().values, a.get_stats().values)


func test_item_roundtrip_all_rarities() -> void:
	var rng := Rng.make(21)
	var base := db.get_base(&"crypt_blade")
	for rarity: Enums.Rarity in Enums.Rarity.values():
		var item := gen.create_item(base, rarity, 8, rng)
		_assert_same(item, _roundtrip(item))


func test_unknown_base_returns_null() -> void:
	assert_null(ItemSerializer.item_from_dict({"base": "gibt_es_nicht"}, db))
	assert_null(ItemSerializer.item_from_dict({}, db))


func test_inventory_and_equipment_roundtrip() -> void:
	var rng := Rng.make(22)
	var inv: Inventory = add_child_autofree(Inventory.new())
	var eq: Equipment = add_child_autofree(Equipment.new())
	inv.add_gold(77)
	var ring := gen.create_item(db.get_base(&"gold_ring"), Enums.Rarity.RARE, 6, rng)
	var axe := gen.create_item(db.get_base(&"war_axe"), Enums.Rarity.LEGENDARY, 6, rng)
	inv.place_item(ring, Vector2i(3, 2))
	eq.equip(axe)
	var inv_data: Dictionary = JSON.parse_string(
		JSON.stringify(ItemSerializer.inventory_to_dict(inv))
	)
	var eq_data: Dictionary = JSON.parse_string(
		JSON.stringify(ItemSerializer.equipment_to_dict(eq))
	)
	var inv2: Inventory = add_child_autofree(Inventory.new())
	var eq2: Equipment = add_child_autofree(Equipment.new())
	ItemSerializer.inventory_from_dict(inv2, inv_data, db)
	ItemSerializer.equipment_from_dict(eq2, eq_data, db)
	assert_eq(inv2.gold, 77)
	assert_eq(inv2.get_item_count(), 1)
	_assert_same(ring, inv2.get_item_at(Vector2i(3, 2)))
	_assert_same(axe, eq2.get_item(Enums.Slot.WEAPON))
	assert_eq(eq2.get_bonus_stats().values, eq.get_bonus_stats().values)
