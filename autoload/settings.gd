extends Node
## Einstellungen des Spielers, gespeichert in user://settings.cfg.
## Grafikstufen und ihre Wirkung baut AP1 aus, die Menüs AP7.

signal changed

enum Quality { LOW, MEDIUM, HIGH, ULTRA }

const PATH := "user://settings.cfg"

var quality: Quality = Quality.HIGH
var fullscreen: bool = false
var vsync: bool = true
var master_volume: float = 1.0
var show_debug_overlay: bool = false

# --- Ergänzt von AP7 (Einstellungsmenü) ---

## Lautstärke der Busse „Music“ und „Effects“ (0 bis 1). Fehlt der Bus, passiert nichts.
var music_volume: float = 0.8
var effects_volume: float = 1.0
## Eigene Tastenbelegung: Aktion → physical_keycode. Ersetzt die erste Taste der Aktion,
## Maustasten bleiben. Leer = Belegung aus project.godot.
var key_bindings: Dictionary[StringName, int] = {}


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	quality = cfg.get_value("graphics", "quality", quality)
	fullscreen = cfg.get_value("graphics", "fullscreen", fullscreen)
	vsync = cfg.get_value("graphics", "vsync", vsync)
	master_volume = cfg.get_value("audio", "master_volume", master_volume)
	show_debug_overlay = cfg.get_value("debug", "show_overlay", show_debug_overlay)
	music_volume = cfg.get_value("audio", "music_volume", music_volume)
	effects_volume = cfg.get_value("audio", "effects_volume", effects_volume)
	key_bindings.clear()
	var bindings: Variant = cfg.get_value("controls", "key_bindings", {})
	if bindings is Dictionary:
		for action: Variant in bindings:
			key_bindings[StringName(action)] = int(bindings[action])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.set_value("graphics", "vsync", vsync)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("debug", "show_overlay", show_debug_overlay)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "effects_volume", effects_volume)
	var bindings := {}
	for action: StringName in key_bindings:
		bindings[String(action)] = key_bindings[action]
	cfg.set_value("controls", "key_bindings", bindings)
	cfg.save(PATH)


## Wendet die Einstellungen auf Fenster und Ton an.
func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("Effects", effects_volume)
	_apply_key_bindings()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
		)
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	changed.emit()


## Belegt eine Aktion mit einer anderen Taste (physical_keycode). Wirkt sofort, speichert nicht.
func set_key_binding(action: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action):
		return
	key_bindings[action] = physical_keycode
	_apply_key_bindings()


## Alle Tasten zurück auf die Belegung aus project.godot. Wirkt sofort, speichert nicht.
func reset_key_bindings() -> void:
	key_bindings.clear()
	InputMap.load_from_project_settings()


## Erste Taste einer Aktion (physical_keycode), KEY_NONE wenn sie keine hat.
static func get_key_binding(action: StringName) -> Key:
	if not InputMap.has_action(action):
		return KEY_NONE
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	return KEY_NONE


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))


func _apply_key_bindings() -> void:
	for action: StringName in key_bindings:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
				break
		var key := InputEventKey.new()
		key.physical_keycode = key_bindings[action] as Key
		InputMap.action_add_event(action, key)
