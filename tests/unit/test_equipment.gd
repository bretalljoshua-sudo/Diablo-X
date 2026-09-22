extends GutTest
## Ausrüsten mit Neuberechnung der Werte (AP4 „Fertig, wenn“: Ausrüsten verändert die Werte).

const PlayerScript := preload("res://debug/loot_test_player.gd")

var equipment: Equipment
var inventory: Inventory
var db: ItemDatabase


func before_each() -> void:
	db = ItemDatabase.get_default()
	var owner_node: Node3D = add_child_autofree(Node3D.new())
	equipment = Equipment.new()
	inventory = Inventory.new()
	owner_node.add_child(equipment)
	owner_node.add_child(inventory)


func _item(base_id: StringName, damage_affix: float = 0.0) -> ItemInstance:
	var item := ItemInstance.new()
	item.base = db.get_base(base_id)
	item.item_level = 5
	if damage_affix > 0.0:
		var roll := AffixRoll.new()
		roll.affix = db.get_affix(&"damage_weapon")
		roll.value = damage_affix
		item.affixes.append(roll)
		item.rarity = Enums.Rarity.MAGIC
	return item


func test_equip_changes_bonus_stats() -> void:
	watch_signals(equipment)
	assert_eq(equipment.get_bonus_stats().get_value(Enums.Stat.DAMAGE), 0.0)
	var sword := _item(&"rusty_sword", 5.0)
	assert_null(equipment.equip(sword))
	assert_eq(equipment.get_bonus_stats().get_value(Enums.Stat.DAMAGE), 13.0, "8 Grund + 5 Affix")
	assert_signal_emitted(equipment, "stats_changed")
	var base := StatBlock.from_dict({Enums.Stat.DAMAGE: 10.0})
	assert_eq(equipment.apply_to(base).get_value(Enums.Stat.DAMAGE), 23.0)


func test_equip_replaces_and_returns_previous() -> void:
	var old := _item(&"rusty_sword")
	var new := _item(&"war_axe")
	equipment.equip(old)
	assert_eq(equipment.equip(new), old)
	assert_eq(equipment.get_item(Enums.Slot.WEAPON), new)
	assert_eq(equipment.get_bonus_stats().get_value(Enums.Stat.DAMAGE), 14.0)


func test_wrong_slot_is_rejected() -> void:
	var helm := _item(&"leather_cap")
	assert_eq(equipment.equip(helm, Enums.Slot.WEAPON), helm, "passt nicht, bleibt in der Hand")
	assert_null(equipment.get_item(Enums.Slot.WEAPON))


func test_rings_use_both_slots() -> void:
	var a := _item(&"copper_ring")
	var b := _item(&"gold_ring")
	equipment.equip(a)
	equipment.equip(b)
	assert_eq(equipment.get_item(Enums.Slot.RING_1), a)
	assert_eq(equipment.get_item(Enums.Slot.RING_2), b)
	var c := _item(&"gold_ring")
	assert_eq(equipment.equip(c), a, "ersetzt den schwächeren Ring")


func test_unequip_emits_null() -> void:
	watch_signals(EventBus)
	var boots := _item(&"leather_boots")
	equipment.equip(boots)
	assert_signal_emitted_with_parameters(EventBus, "player_equipped", [Enums.Slot.BOOTS, boots])
	assert_eq(equipment.unequip(Enums.Slot.BOOTS), boots)
	assert_signal_emitted_with_parameters(EventBus, "player_equipped", [Enums.Slot.BOOTS, null])
	assert_eq(equipment.get_bonus_stats().get_value(Enums.Stat.ARMOR), 0.0)


func test_equip_from_inventory_swaps() -> void:
	var old := _item(&"rusty_sword")
	var new := _item(&"war_axe")
	equipment.equip(old)
	inventory.add_item(new)
	var cell := inventory.get_position_of(new)
	assert_true(equipment.equip_from_inventory(inventory, new))
	assert_eq(equipment.get_item(Enums.Slot.WEAPON), new)
	assert_true(inventory.has_item(old))
	assert_eq(
		inventory.get_position_of(old), cell, "alter Gegenstand an der frei gewordenen Stelle"
	)
	assert_false(inventory.has_item(new))


func test_equip_from_inventory_rolls_back_without_space() -> void:
	inventory.width = 1
	inventory.height = 1
	var old := _item(&"rusty_sword")
	var ring := _item(&"copper_ring")
	equipment.equip(old)
	inventory.add_item(ring)
	assert_false(equipment.equip_from_inventory(inventory, ring, Enums.Slot.WEAPON))
	assert_eq(equipment.get_item(Enums.Slot.WEAPON), old)
	assert_true(inventory.has_item(ring))


func test_unequip_to_inventory() -> void:
	var helm := _item(&"iron_helm")
	equipment.equip(helm)
	assert_true(equipment.unequip_to_inventory(inventory, Enums.Slot.HELM))
	assert_true(inventory.has_item(helm))
	assert_null(equipment.get_item(Enums.Slot.HELM))


func test_aspects_for_tags() -> void:
	var item := _item(&"war_axe")
	item.rarity = Enums.Rarity.LEGENDARY
	item.aspect = db.get_aspect(&"aspect_maelstrom")
	equipment.equip(item)
	assert_eq(equipment.get_aspects().size(), 1)
	assert_eq(equipment.get_aspects_for_tags([&"whirlwind", &"core"]).size(), 1)
	assert_true(equipment.get_aspects_for_tags([&"leap"]).is_empty())


func test_stats_service_sees_equipment() -> void:
	# Platzhalter-Spieler rechnet Grundwerte + Ausrüstung, der Stats-Dienst liest sie.
	var player: Node3D = PlayerScript.new()
	var eq := Equipment.new()
	eq.name = "Equipment"
	var inv := Inventory.new()
	inv.name = "Inventory"
	player.add_child(eq)
	player.add_child(inv)
	add_child_autofree(player)
	var before := Stats.get_stat(player, Enums.Stat.DAMAGE)
	var armor_before := Stats.get_stat(player, Enums.Stat.ARMOR)
	eq.equip(_item(&"war_axe", 6.0))
	eq.equip(_item(&"chainmail"))
	assert_eq(Stats.get_stat(player, Enums.Stat.DAMAGE), before + 20.0)
	assert_eq(Stats.get_stat(player, Enums.Stat.ARMOR), armor_before + 22.0)
	eq.unequip(Enums.Slot.WEAPON)
	assert_eq(Stats.get_stat(player, Enums.Stat.DAMAGE), before)
