extends SimTest
## Testszene loot_test (AP4): Beute liegt am Boden, aufsammeln, besseres anlegen,
## die Werte der Figur steigen.


func test_pick_up_and_equip_raises_stats() -> void:
	var scene := await load_scene("loot_test")
	var grounds := get_tree().get_nodes_in_group(GroundItem.GROUP)
	assert_gt(grounds.size(), 3, "Startbeute liegt am Boden")
	var player: Node3D = scene.player
	var damage_before := Stats.get_stat(player, Enums.Stat.DAMAGE)
	var armor_before := Stats.get_stat(player, Enums.Stat.ARMOR)
	var picked: int = scene.pick_up_all()
	await wait_process_frames(2)
	assert_eq(picked, grounds.size())
	assert_true(get_tree().get_nodes_in_group(GroundItem.GROUP).is_empty())
	assert_gt(scene.inventory.gold, 0, "Gold aufgesammelt")
	var equipped: int = scene.equip_upgrades()
	assert_gt(equipped, 0)
	var after := (
		Stats.get_stat(player, Enums.Stat.DAMAGE) + Stats.get_stat(player, Enums.Stat.ARMOR)
	)
	assert_gt(after, damage_before + armor_before, "Ausrüstung erhöht die Werte")


func test_simulation_and_selling() -> void:
	var scene := await load_scene("loot_test")
	var text: String = scene.simulate(200)
	assert_true(text.begins_with("200 Drops"), text)
	scene.pick_up_all()
	var gold_before: int = scene.inventory.gold
	assert_gt(scene.sell_all(), 0)
	assert_gt(scene.inventory.gold, gold_before)
	assert_eq(scene.inventory.get_item_count(), 0)
