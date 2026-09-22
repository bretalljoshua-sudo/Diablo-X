extends UiSimTest
## HUD, Balken, Minikarte, Händler, Beute-Beschriftungen und Einstellungen.


func test_orbs_potion_and_experience_follow_signals() -> void:
	EventBus.player_health_changed.emit(50.0, 200.0)
	EventBus.potion_charges_changed.emit(2, 4, 0.5)
	EventBus.experience_changed.emit(30, 120, 3)
	assert_eq(ui.hud.potion.charges, 2)
	await wait_process_frames(1)
	assert_almost_eq(ui.hud.life_orb.get_fill(), 0.25, 0.001)
	assert_almost_eq(ui.hud.experience.get_ratio(), 0.25, 0.001)
	assert_eq(ui.hud.level_label.text, "Stufe 3")
	# Heiltrank der Testszene über die Taste Q.
	Game.player.set(&"health", 10.0)
	await tap_action(&"potion")
	assert_gt(ui.hud.life_orb.value, 10.0, "Trank heilt, Kugel steigt")


func test_enemy_bars_and_boss_bar() -> void:
	var dummy: Node3D = scene.get(&"dummies")[0]
	EventBus.entity_health_changed.emit(dummy, 40.0, 120.0)
	assert_true(ui.enemy_bars.has_bar(dummy), "Balken nach Schaden")
	EventBus.entity_died.emit(dummy, null)
	assert_false(ui.enemy_bars.has_bar(dummy), "Balken weg nach dem Tod")
	EventBus.hovered_target_changed.emit(dummy)
	assert_eq(ui.enemy_bars.hovered, dummy)
	assert_eq(EnemyHealthBars.display_name_of(dummy), "Skelettkrieger")

	scene.call(&"toggle_boss")
	var boss: Node3D = scene.get(&"boss")
	assert_true(ui.hud.boss_bar.visible, "Bossbalken erscheint")
	assert_eq(ui.hud.boss_bar.boss_name, "Der Gruftwächter")
	EventBus.entity_health_changed.emit(boss, 500.0, 2000.0)
	assert_almost_eq(ui.hud.boss_bar.get_ratio(), 0.25, 0.001)
	assert_false(ui.enemy_bars.entries.has(boss), "Boss hat keinen kleinen Balken")
	EventBus.boss_phase_changed.emit(boss, 2)
	assert_eq(ui.hud.boss_bar.phase, 2)
	EventBus.boss_encounter_ended.emit(boss)
	assert_false(ui.hud.boss_bar.visible, "Bossbalken verschwindet")


func test_minimap_reveals_around_player() -> void:
	var minimap := ui.hud.minimap
	assert_not_null(minimap.texture, "Karte aus dem Layout gebaut")
	var start := minimap.revealed_count
	assert_gt(start, 0, "um den Start aufgedeckt")
	Game.player.global_position = Vector3(30, 0, 0)
	await wait_seconds(0.3)
	assert_gt(minimap.revealed_count, start, "Laufen deckt mehr auf")
	await tap_action(&"open_map")
	assert_true(minimap.big)
	await tap_action(&"open_map")
	assert_false(minimap.big)


func test_merchant_buy_and_sell_with_mouse() -> void:
	var inventory := player_inventory()
	inventory.clear()
	scene.call(&"open_merchant")
	await wait_process_frames(2)
	assert_true(ui.merchant_window.is_open(), "Händler offen")
	assert_true(ui.inventory_window.is_open(), "Inventar öffnet mit")
	var item: ItemInstance = ui.merchant_window.stock[0]
	var price := ItemValue.buy_price(item)
	var gold := inventory.gold
	await click_control(ui.merchant_window.get_tile(item))
	assert_true(inventory.has_item(item), "gekauft")
	assert_eq(inventory.gold, gold - price)
	assert_false(item in ui.merchant_window.stock, "aus dem Angebot entfernt")
	await wait_process_frames(1)
	var cell := inventory.get_position_of(item)
	await click(ui.inventory_window.grid.cell_global_center(cell), MOUSE_BUTTON_RIGHT)
	assert_false(inventory.has_item(item), "Rechtsklick verkauft beim Händler")
	assert_eq(inventory.gold, gold - price + ItemValue.sell_value(item))
	await tap_action(&"pause")
	assert_false(ui.merchant_window.is_open())
	assert_false(ui.inventory_window.is_open())


func test_ground_labels_pick_up_on_click() -> void:
	var inventory := player_inventory()
	inventory.clear()
	ui.ground_labels.force_visible = true
	await wait_process_frames(2)
	assert_gt(ui.ground_labels.label_rects.size(), 0, "Schilder für Beute am Boden")
	var ground: GroundItem = null
	for candidate: GroundItem in ui.ground_labels.label_rects:
		if candidate.item != null:
			ground = candidate
			break
	assert_not_null(ground)
	var item := ground.item
	await click(ui.ground_labels.label_rects[ground].get_center())
	assert_true(inventory.has_item(item), "Klick auf das Schild hebt auf")


func test_settings_volume_and_key_binding() -> void:
	var volume := Settings.master_volume
	await tap_action(&"pause")
	ui.pause_menu.show_settings()
	var panel := ui.pause_menu.settings
	panel.volume_sliders[&"master"].value = 40.0
	assert_almost_eq(Settings.master_volume, 0.4, 0.001, "Regler ändert die Lautstärke")
	panel.current_tab = 2
	await wait_process_frames(1)
	var button := panel.binding_buttons[&"open_inventory"]
	(button.get_parent().get_parent().get_parent() as ScrollContainer).ensure_control_visible(
		button
	)
	await wait_process_frames(2)
	await click_control(button)
	assert_true(panel.is_capturing(), "wartet auf eine Taste")
	await press_key(KEY_B)
	assert_false(panel.is_capturing())
	assert_eq(Settings.get_key_binding(&"open_inventory"), KEY_B, "I ist jetzt B")
	await tap_action(&"pause")
	await tap_action(&"pause")
	assert_false(ui.pause_menu.is_open())
	await press_key(KEY_B)
	assert_true(ui.inventory_window.is_open(), "B öffnet jetzt das Inventar")
	Settings.master_volume = volume
	Settings.apply()
