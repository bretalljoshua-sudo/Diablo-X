extends Node
## Autoload „Screenshot“.
## - F12 speichert einen Screenshot nach user://screenshots/.
## - Kommandozeile: --screenshot=<datei.png> [--screenshot-frames=90]
##   macht nach N Bildern automatisch einen Screenshot und beendet das Spiel.
##   Gedacht für Vorher/Nachher-Vergleiche am PC (AP1). Relative Dateinamen landen in
##   user://screenshots/, der volle Pfad steht im Log.

const DEFAULT_FRAMES := 90

var _auto_path: String = ""
var _frames_left: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--screenshot="):
			_auto_path = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--screenshot-frames="):
			_frames_left = arg.trim_prefix("--screenshot-frames=").to_int()
	if _frames_left <= 0:
		_frames_left = DEFAULT_FRAMES
	set_process(not _auto_path.is_empty())


func _process(_delta: float) -> void:
	_frames_left -= 1
	if _frames_left > 0:
		return
	set_process(false)
	take(_auto_path)
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"screenshot"):
		take()


## Speichert das aktuelle Bild als PNG und liefert den Pfad, oder "" ohne Bildschirm.
func take(path: String = "") -> String:
	if DisplayServer.get_name() == "headless":
		push_warning("Screenshot: ohne Bildschirm (headless) nicht möglich.")
		return ""
	var image := get_viewport().get_texture().get_image()
	if path.is_empty():
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		path = "user://screenshots/%s.png" % stamp
	elif not path.is_absolute_path():
		path = "user://screenshots/".path_join(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := image.save_png(path)
	if err != OK:
		push_error("Screenshot: konnte %s nicht speichern (%s)." % [path, error_string(err)])
		return ""
	print("Screenshot: %s" % ProjectSettings.globalize_path(path))
	return path
