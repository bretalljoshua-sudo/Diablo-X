class_name SettingsPanel
extends TabContainer
## Einstellungen mit den Reitern Grafik, Ton und Steuerung. Änderungen wirken sofort über
## Settings.apply(); speichern erst mit save() (Knopf „Speichern“ im Pausenmenü).

## Belegbare Aktionen mit deutschem Namen. Maustasten und Esc bleiben fest.
const BINDABLE_ACTIONS: Dictionary[StringName, String] = {
	&"move_up": "Laufen nach oben",
	&"move_down": "Laufen nach unten",
	&"move_left": "Laufen nach links",
	&"move_right": "Laufen nach rechts",
	&"dodge": "Ausweichen",
	&"potion": "Heiltrank",
	&"skill_1": "Skill 1",
	&"skill_2": "Skill 2",
	&"skill_3": "Skill 3",
	&"skill_4": "Skill 4",
	&"show_item_labels": "Beute beschriften (halten)",
	&"open_inventory": "Inventar",
	&"open_skills": "Skillbaum",
	&"open_map": "Karte",
	&"toggle_debug_overlay": "Debug-Anzeige",
	&"screenshot": "Bildschirmfoto",
}

var quality_option: OptionButton
var fullscreen_check: CheckButton
var vsync_check: CheckButton
var debug_check: CheckButton
var volume_sliders: Dictionary[StringName, HSlider] = {}
var binding_buttons: Dictionary[StringName, Button] = {}
## Aktion, die gerade auf eine neue Taste wartet (leer = keine).
var capturing_action: StringName = &""


func _init() -> void:
	name = "SettingsPanel"
	custom_minimum_size = Vector2(560, 440)
	_build_graphics()
	_build_audio()
	_build_controls()


## Liest die aktuellen Werte aus Settings in die Bedienelemente.
func load_from_settings() -> void:
	quality_option.select(Settings.quality)
	fullscreen_check.set_pressed_no_signal(Settings.fullscreen)
	vsync_check.set_pressed_no_signal(Settings.vsync)
	debug_check.set_pressed_no_signal(Settings.show_debug_overlay)
	volume_sliders[&"master"].set_value_no_signal(Settings.master_volume * 100.0)
	volume_sliders[&"music"].set_value_no_signal(Settings.music_volume * 100.0)
	volume_sliders[&"effects"].set_value_no_signal(Settings.effects_volume * 100.0)
	_refresh_bindings()


func save() -> void:
	Settings.save_settings()


## Wartet auf die nächste Taste für action.
func start_capture(action: StringName) -> void:
	capturing_action = action
	_refresh_bindings()


func is_capturing() -> bool:
	return not String(capturing_action).is_empty()


## Belegt die wartende Aktion mit einer Taste. Esc bricht ab.
func finish_capture(physical_keycode: Key) -> void:
	if not is_capturing():
		return
	if physical_keycode != KEY_ESCAPE:
		Settings.set_key_binding(capturing_action, physical_keycode)
	capturing_action = &""
	_refresh_bindings()


func reset_bindings() -> void:
	capturing_action = &""
	Settings.reset_key_bindings()
	_refresh_bindings()


func _input(event: InputEvent) -> void:
	if not is_capturing() or not is_visible_in_tree():
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		finish_capture(code)
		get_viewport().set_input_as_handled()


func _build_graphics() -> void:
	var page := _page("Grafik")
	quality_option = OptionButton.new()
	quality_option.name = "Quality"
	# Namen der Grafikstufen aus den Voreinstellungen von AP1 (graphics/quality/*.tres).
	var quality_names := Graphics.get_quality_names()
	for i in quality_names.size():
		quality_option.add_item(quality_names[i], i)
	quality_option.item_selected.connect(
		func(index: int) -> void:
			Settings.quality = index as Settings.Quality
			Settings.apply()
	)
	_row(page, "Grafikqualität", quality_option)
	fullscreen_check = CheckButton.new()
	fullscreen_check.name = "Fullscreen"
	fullscreen_check.toggled.connect(
		func(on: bool) -> void:
			Settings.fullscreen = on
			Settings.apply()
			if not on and DisplayServer.get_name() != "headless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	)
	_row(page, "Vollbild", fullscreen_check)
	vsync_check = CheckButton.new()
	vsync_check.name = "VSync"
	vsync_check.toggled.connect(
		func(on: bool) -> void:
			Settings.vsync = on
			Settings.apply()
	)
	_row(page, "Vertikale Synchronisation", vsync_check)
	debug_check = CheckButton.new()
	debug_check.name = "DebugOverlay"
	debug_check.toggled.connect(
		func(on: bool) -> void:
			Settings.show_debug_overlay = on
			Settings.apply()
	)
	_row(page, "Debug-Anzeige (F3)", debug_check)
	var note := Label.new()
	note.theme_type_variation = &"MutedLabel"
	note.text = "Die Wirkung der Grafikstufen baut Paket AP1."
	page.add_child(note)


func _build_audio() -> void:
	var page := _page("Ton")
	for entry: Array in [
		[&"master", "Gesamtlautstärke"], [&"music", "Musik"], [&"effects", "Effekte"]
	]:
		var slider := HSlider.new()
		slider.name = String(entry[0]).capitalize() + "Volume"
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.custom_minimum_size.x = 240
		var key: StringName = entry[0]
		slider.value_changed.connect(func(value: float) -> void: _set_volume(key, value / 100.0))
		_row(page, entry[1], slider)
		volume_sliders[key] = slider


func _build_controls() -> void:
	var page := _page("Steuerung")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 320
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for action: StringName in BINDABLE_ACTIONS:
		var button := Button.new()
		button.name = "Bind_" + String(action)
		button.custom_minimum_size.x = 160
		button.pressed.connect(start_capture.bind(action))
		_row(list, BINDABLE_ACTIONS[action], button)
		binding_buttons[action] = button
	var reset := Button.new()
	reset.name = "ResetBindings"
	reset.text = "Standardbelegung"
	reset.pressed.connect(reset_bindings)
	page.add_child(reset)


func _refresh_bindings() -> void:
	for action: StringName in binding_buttons:
		var key := Settings.get_key_binding(action)
		var text := OS.get_keycode_string(key) if key != KEY_NONE else "—"
		if action == capturing_action:
			text = "Taste drücken …"
		binding_buttons[action].text = text


func _set_volume(key: StringName, volume: float) -> void:
	match key:
		&"master":
			Settings.master_volume = volume
		&"music":
			Settings.music_volume = volume
		&"effects":
			Settings.effects_volume = volume
	Settings.apply()


func _page(title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = title
	page.add_theme_constant_override(&"separation", 10)
	add_child(page)
	return page


func _row(parent: Control, caption: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)
	parent.add_child(row)
