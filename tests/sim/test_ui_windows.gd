extends UiSimTest
## Fenster öffnen und schließen über die Tastenkürzel I, K, M und Esc sowie die Menüknöpfe.


func test_hotkeys_toggle_windows() -> void:
	assert_false(ui.inventory_window.is_open())
	await tap_action(&"open_inventory")
	assert_true(ui.inventory_window.is_open(), "I öffnet das Inventar")
	await tap_action(&"open_skills")
	assert_true(ui.skill_tree_window.is_open(), "K öffnet den Skillbaum")
	await tap_action(&"open_map")
	assert_true(ui.hud.minimap.big, "M öffnet die große Karte")
	await tap_action(&"open_inventory")
	assert_false(ui.inventory_window.is_open(), "I schließt das Inventar wieder")
	await tap_action(&"pause")
	assert_false(ui.skill_tree_window.is_open(), "Esc schließt offene Fenster")
	assert_false(ui.hud.minimap.big, "Esc schließt die Karte")
	assert_false(ui.pause_menu.is_open(), "Esc öffnet dabei nicht das Menü")


func test_escape_opens_pause_menu_and_pauses() -> void:
	await tap_action(&"pause")
	assert_true(ui.pause_menu.is_open())
	assert_true(get_tree().paused, "Spiel ist angehalten")
	await tap_action(&"open_inventory")
	assert_false(ui.inventory_window.is_open(), "Im Pausenmenü öffnet I nichts")
	ui.pause_menu.show_settings()
	await tap_action(&"pause")
	assert_true(ui.pause_menu.is_open(), "Esc in den Einstellungen geht zurück ins Menü")
	assert_true(ui.pause_menu.main_page.visible)
	await tap_action(&"pause")
	assert_false(ui.pause_menu.is_open())
	assert_false(get_tree().paused, "Spiel läuft weiter")


func test_menu_buttons_open_windows_with_mouse() -> void:
	var button := ui.hud.find_child("InventarButton", true, false) as Button
	assert_not_null(button)
	await click_control(button)
	assert_true(ui.inventory_window.is_open(), "Knopf Inventar öffnet das Inventar")
	var close := ui.inventory_window.find_child("CloseButton", true, false) as Button
	await click_control(close)
	assert_false(ui.inventory_window.is_open(), "Kreuz schließt das Fenster")
	await click_control(ui.hud.find_child("MenüButton", true, false) as Button)
	assert_true(ui.pause_menu.is_open(), "Knopf Menü öffnet das Pausenmenü")
	await click_control(ui.pause_menu.resume_button)
	assert_false(ui.pause_menu.is_open(), "Weiter schließt das Pausenmenü")


func test_window_signals_reach_event_bus() -> void:
	watch_signals(EventBus)
	await tap_action(&"open_inventory")
	assert_signal_emitted_with_parameters(EventBus, "ui_window_toggled", [&"inventory", true])
	await tap_action(&"open_inventory")
	assert_signal_emitted_with_parameters(EventBus, "ui_window_toggled", [&"inventory", false])
	assert_false(ui.is_any_window_open())
