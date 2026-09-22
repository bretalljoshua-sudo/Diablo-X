extends GutTest
## Kleine Bausteine der UI (AP7) ohne Szene.


func test_gold_is_formatted_with_dots() -> void:
	assert_eq(InventoryWindow.format_gold(0), "0")
	assert_eq(InventoryWindow.format_gold(999), "999")
	assert_eq(InventoryWindow.format_gold(1500), "1.500")
	assert_eq(InventoryWindow.format_gold(1234567), "1.234.567")


func test_skill_initials_for_placeholder_icons() -> void:
	var skill := SkillDef.new()
	skill.display_name = "Zorn der Ahnen"
	assert_eq(SkillBar.initials(skill), "ZA")
	skill.display_name = "Wirbelsturm"
	assert_eq(SkillBar.initials(skill), "Wi")
	assert_eq(SkillBar.initials(null), "?")


func test_theme_has_dark_panels_and_buttons() -> void:
	var theme := UiTheme.get_theme()
	assert_same(theme, UiTheme.get_theme(), "Theme wird nur einmal gebaut")
	assert_true(theme.has_stylebox(&"panel", &"PanelContainer"))
	assert_true(theme.has_stylebox(&"normal", &"Button"))
	assert_eq(theme.get_color(&"font_color", &"TitleLabel"), UiTheme.TEXT_TITLE)


func test_inventory_grid_maps_cells() -> void:
	var inventory := Inventory.new()
	var grid := InventoryGrid.new()
	grid.set_inventory(inventory)
	assert_eq(grid.cell_at(Vector2(10, 10)), Vector2i(0, 0))
	assert_eq(
		grid.cell_at(Vector2(InventoryGrid.CELL * 3.5, InventoryGrid.CELL * 1.2)), Vector2i(3, 1)
	)
	assert_eq(grid.cell_at(Vector2(-1, 5)), InventoryGrid.INVALID)
	assert_eq(grid.cell_at(Vector2(InventoryGrid.CELL * 10.5, 5)), InventoryGrid.INVALID)
	grid.free()
	inventory.free()


func test_tooltip_text_for_empty_slot_is_all_green() -> void:
	var item := ItemInstance.new()
	item.base = ItemDatabase.get_default().get_base(&"rusty_sword")
	var text := ItemTooltip.item_bbcode(item, null, true)
	assert_string_contains(text, "Platz ist leer")
	assert_string_contains(text, UiTheme.hex(UiTheme.BETTER))
	assert_false(text.contains(UiTheme.hex(UiTheme.WORSE)), "nichts wird schlechter")
	assert_string_contains(text, "Verkaufswert")


func test_skill_tree_only_requests_allowed_rank_ups() -> void:
	var window := SkillTreeWindow.new()
	var skill := SkillDef.new()
	skill.id = &"strike"
	var state := SkillTreeState.new()
	state.skills.append(skill)
	window.set_state(state)
	watch_signals(EventBus)
	assert_false(window.request_rank_up(skill), "ohne Punkte keine Anfrage")
	state.points = 1
	state.unlocked.append(&"strike")
	window.set_state(state)
	assert_true(window.request_rank_up(skill))
	assert_signal_emitted_with_parameters(EventBus, "skill_rank_up_requested", [skill])
	assert_false(window.request_slot_assign(2, skill), "ungelernte Skills nicht auf die Leiste")
	window.free()


func test_enemy_bar_uses_position_from_enemy() -> void:
	var plain := Node3D.new()
	add_child_autofree(plain)
	plain.global_position = Vector3(1, 0, 2)
	var expected := Vector3(1, EnemyHealthBars.HEAD_HEIGHT, 2)
	assert_eq(EnemyHealthBars.bar_world_position(plain), expected)
	var enemy := Node3D.new()
	var script := GDScript.new()
	script.source_code = (
		"\n"
		. join(
			[
				"extends Node3D",
				"func get_health_bar_position() -> Vector3:",
				"\treturn Vector3(0, 5, 0)",
			]
		)
	)
	script.reload()
	enemy.set_script(script)
	add_child_autofree(enemy)
	assert_eq(EnemyHealthBars.bar_world_position(enemy), Vector3(0, 5, 0))
