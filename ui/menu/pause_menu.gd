class_name PauseMenu
extends Control
## Pausenmenü (Esc): hält das Spiel an (SceneTree.paused), bietet Weiter, Einstellungen und
## Beenden. Esc im Einstellungsmenü geht zurück, Esc im Hauptmenü setzt das Spiel fort.

signal quit_requested

var main_page: VBoxContainer
var settings_page: VBoxContainer
var settings: SettingsPanel
var resume_button: Button


func _init() -> void:
	name = "PauseMenu"
	theme = UiTheme.get_theme()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var pages := VBoxContainer.new()
	panel.add_child(pages)

	main_page = VBoxContainer.new()
	main_page.name = "Main"
	main_page.custom_minimum_size.x = 320
	main_page.add_theme_constant_override(&"separation", 10)
	pages.add_child(main_page)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Pause"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_page.add_child(title)
	resume_button = _button(main_page, "Weiter", close_menu)
	_button(main_page, "Einstellungen", show_settings)
	_button(main_page, "Spiel beenden", _on_quit)

	settings_page = VBoxContainer.new()
	settings_page.name = "Settings"
	settings_page.visible = false
	settings_page.add_theme_constant_override(&"separation", 10)
	pages.add_child(settings_page)
	var settings_title := Label.new()
	settings_title.theme_type_variation = &"TitleLabel"
	settings_title.text = "Einstellungen"
	settings_page.add_child(settings_title)
	settings = SettingsPanel.new()
	settings_page.add_child(settings)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override(&"separation", 8)
	settings_page.add_child(buttons)
	_button(buttons, "Speichern", func() -> void: settings.save()).name = "SaveButton"
	_button(buttons, "Zurück", show_main).name = "BackButton"


func is_open() -> bool:
	return visible


func open_menu() -> void:
	visible = true
	show_main()
	get_tree().paused = true
	EventBus.ui_window_toggled.emit(&"pause", true)


func close_menu() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	EventBus.ui_window_toggled.emit(&"pause", false)


func show_settings() -> void:
	main_page.visible = false
	settings_page.visible = true
	settings.load_from_settings()
	settings.current_tab = 0


func show_main() -> void:
	settings_page.visible = false
	main_page.visible = true
	resume_button.grab_focus.call_deferred()


## Esc: aus den Einstellungen zurück, sonst weiterspielen. Beim Tastenbelegen bricht Esc nur ab.
func handle_cancel() -> void:
	if settings.is_capturing():
		return
	if settings_page.visible:
		show_main()
	else:
		close_menu()


func _on_quit() -> void:
	quit_requested.emit()
	close_menu()
	get_tree().quit()


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = text.replace(" ", "") + "Button"
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button
