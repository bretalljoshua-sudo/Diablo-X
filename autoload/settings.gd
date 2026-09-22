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
var show_debug_overlay: bool = true


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


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.set_value("graphics", "vsync", vsync)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("debug", "show_overlay", show_debug_overlay)
	cfg.save(PATH)


## Wendet die Einstellungen auf Fenster und Ton an.
func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
		)
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	changed.emit()
