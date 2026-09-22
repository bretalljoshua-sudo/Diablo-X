extends UiSimTest
## „Fertig, wenn“ von AP7, Teil 1: ein kompletter Ausrüstungswechsel mit Maus und mit Tastatur,
## gegen echte Gegenstände, Inventar und Ausrüstung aus AP4.

var inventory: Inventory
var equipment: Equipment


func before_each() -> void:
	await super()
	inventory = player_inventory()
	equipment = player_equipment()
	equipment.clear()
	inventory.clear()
	await tap_action(&"open_inventory")
	assert_true(ui.inventory_window.is_open())


func test_full_equipment_with_right_click() -> void:
	var items := make_item_set(Enums.Rarity.MAGIC, 1)
	assert_eq(items.size(), Enums.Slot.size(), "ein Gegenstand je Platz")
	for item in items:
		assert_true(inventory.add_item(item))
	await wait_process_frames(1)
	for item in items:
		var cell := inventory.get_position_of(item)
		await click(ui.inventory_window.grid.cell_global_center(cell), MOUSE_BUTTON_RIGHT)
	for slot: Enums.Slot in Enums.Slot.values():
		assert_not_null(equipment.get_item(slot), "Platz %s belegt" % Enums.Slot.keys()[slot])
	assert_eq(inventory.get_item_count(), 0, "Inventar ist leer")
	assert_eq(
		ui.inventory_window.slot_views[Enums.Slot.WEAPON].item,
		equipment.get_item(Enums.Slot.WEAPON)
	)


func test_swap_whole_set_by_drag_to_slots() -> void:
	var old_items := make_item_set(Enums.Rarity.NORMAL, 1)
	for item in old_items:
		equipment.equip(item)
	var new_items := make_item_set(Enums.Rarity.RARE, 3)
	for item in new_items:
		assert_true(inventory.add_item(item))
	var damage_before := Stats.get_stat(Game.player, Enums.Stat.DAMAGE)
	await wait_process_frames(1)
	var ring_slots: Array[Enums.Slot] = [Enums.Slot.RING_1, Enums.Slot.RING_2]
	for item in new_items:
		var slot: Enums.Slot = item.base.slot
		if slot == Enums.Slot.RING_1:
			slot = ring_slots.pop_front()
		# Linksklick nimmt auf, Linksklick auf den Platz legt an.
		await click(ui.inventory_window.grid.cell_global_center(inventory.get_position_of(item)))
		assert_eq(ui.inventory_window.grid.held_item, item, "Gegenstand hängt an der Maus")
		assert_true(ui.inventory_window.slot_views[slot].highlight, "passender Platz leuchtet")
		await click_control(ui.inventory_window.slot_views[slot])
		assert_eq(equipment.get_item(slot), item, "%s angelegt" % item.get_display_name())
	for item in old_items:
		assert_true(inventory.has_item(item), "alter Gegenstand liegt im Inventar")
	assert_gt(Stats.get_stat(Game.player, Enums.Stat.DAMAGE), damage_before, "mehr Schaden")


func test_full_equipment_with_keyboard() -> void:
	var items := make_item_set(Enums.Rarity.MAGIC, 2)
	for item in items:
		assert_true(inventory.add_item(item))
	var grid := ui.inventory_window.grid
	assert_true(grid.has_focus(), "Raster hat beim Öffnen den Fokus")
	for item in items:
		var target := inventory.get_position_of(item)
		while grid.selected_cell.x < target.x:
			await press_key(KEY_RIGHT)
		while grid.selected_cell.x > target.x:
			await press_key(KEY_LEFT)
		while grid.selected_cell.y < target.y:
			await press_key(KEY_DOWN)
		while grid.selected_cell.y > target.y:
			await press_key(KEY_UP)
		assert_eq(grid.selected_cell, target)
		await press_key(KEY_ENTER)
		assert_true(equipment.is_equipped(item), "%s per Enter angelegt" % item.get_display_name())
	assert_eq(inventory.get_item_count(), 0)
	# Ablegen per Tastatur: Platz fokussieren, Enter.
	ui.inventory_window.slot_views[Enums.Slot.HELM].grab_focus()
	await press_key(KEY_ENTER)
	assert_null(equipment.get_item(Enums.Slot.HELM), "Helm per Enter abgelegt")
	assert_eq(inventory.get_item_count(), 1)


func test_unequip_with_right_click_and_move_in_grid() -> void:
	var items := make_item_set(Enums.Rarity.MAGIC, 1)
	equipment.equip(items[Enums.Slot.CHEST])
	await wait_process_frames(1)
	await click_control(ui.inventory_window.slot_views[Enums.Slot.CHEST], MOUSE_BUTTON_RIGHT)
	var chest := items[Enums.Slot.CHEST]
	assert_true(inventory.has_item(chest), "Rechtsklick auf den Platz legt ab")
	var grid := ui.inventory_window.grid
	await click(grid.cell_global_center(inventory.get_position_of(chest)))
	await click(grid.cell_global_center(Vector2i(6, 2)))
	assert_eq(inventory.get_position_of(chest), Vector2i(6, 2), "verschoben per Linksklick")


func test_tooltip_shows_colored_comparison() -> void:
	var weak := make_item_set(Enums.Rarity.NORMAL, 1)[Enums.Slot.WEAPON]
	var strong := make_item_set(Enums.Rarity.NORMAL, 3)[Enums.Slot.WEAPON]
	equipment.equip(weak)
	inventory.add_item(strong)
	await wait_process_frames(1)
	await mouse_move(ui.inventory_window.grid.cell_global_center(inventory.get_position_of(strong)))
	assert_true(ui.tooltip.visible, "Tooltip beim Überfahren")
	assert_eq(ui.tooltip.shown_item, strong)
	assert_eq(ui.tooltip.shown_compare, weak, "Vergleich mit der angelegten Waffe")
	var text := ItemTooltip.item_bbcode(strong, weak, true)
	assert_string_contains(text, UiTheme.hex(UiTheme.BETTER), "bessere Werte grün")
	var reverse := ItemTooltip.item_bbcode(weak, strong, true)
	assert_string_contains(reverse, UiTheme.hex(UiTheme.WORSE), "schlechtere Werte rot")
	await mouse_move(Vector2(5, 5))
	assert_false(ui.tooltip.visible, "Tooltip verschwindet")
