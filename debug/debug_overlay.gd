extends CanvasLayer
## Autoload „DebugOverlay“: FPS, Knotenzahl, Draw Calls, Szene und Seed oben links.
## F3 schaltet die Anzeige ein und aus.

const REFRESH_SEC := 0.25

var _label: Label
var _time_to_refresh: float = 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(12, 8)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	visible = Settings.show_debug_overlay


func _process(delta: float) -> void:
	if not visible:
		return
	_time_to_refresh -= delta
	if _time_to_refresh > 0.0:
		return
	_time_to_refresh = REFRESH_SEC
	_label.text = build_text()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_debug_overlay"):
		visible = not visible
		Settings.show_debug_overlay = visible
		Settings.save_settings()


func build_text() -> String:
	var lines := PackedStringArray()
	(
		lines
		. append(
			(
				"FPS %d   Knoten %d   Draw Calls %d   Speicher %d MB"
				% [
					Performance.get_monitor(Performance.TIME_FPS),
					Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
				]
			)
		)
	)
	lines.append(
		(
			"Szene %s   Seed %d   Godot %s"
			% [Game.current_scene_name, Rng.master_seed, Engine.get_version_info()["string"]]
		)
	)
	lines.append("F3 Anzeige aus   F12 Screenshot")
	return "\n".join(lines)
