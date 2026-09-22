class_name LoadingScreen
extends CanvasLayer
## Ladebildschirm für Ebenenwechsel: schwarzer Hintergrund, Name der Ebene, Hinweis.
## Gehört dem Autoload World und wird über World.travel_to() gezeigt.

const FADE_TIME := 0.25

var _root: Control
var _title: Label
var _subtitle: Label
var _tween: Tween


func _init() -> void:
	layer = 90
	visible = false
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0.01, 0.01, 0.015)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override(&"font_size", 48)
	_title.add_theme_color_override(&"font_color", Color(0.85, 0.75, 0.6))
	box.add_child(_title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override(&"font_color", Color(0.55, 0.5, 0.45))
	box.add_child(_subtitle)


func show_screen(title: String, subtitle: String = "Lädt …") -> void:
	_title.text = title
	_subtitle.text = subtitle
	_kill_tween()
	_root.modulate.a = 1.0
	visible = true


func hide_screen() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(func() -> void: visible = false)


func get_title() -> String:
	return _title.text


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
