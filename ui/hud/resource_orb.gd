class_name ResourceOrb
extends Control
## Lebens- oder Wut-Kugel im HUD. Der Füllstand gleitet zum neuen Wert, verlorene Menge bleibt
## kurz als heller Nachlauf stehen. Die Flüssigkeit zeichnet ein Shader (orb.gdshader).

const SHADER := preload("res://ui/hud/orb.gdshader")
const TRAIL_DELAY := 0.45

@export var caption: String = ""
@export var liquid_color: Color = UiTheme.LIFE

var value: float = 1.0
var max_value: float = 1.0
## Angezeigter Füllstand (0 bis 1), folgt dem Zielwert weich.
var displayed_fill: float = 1.0
var trail_fill: float = 1.0

var _liquid: ColorRect
var _frame: Control
var _trail_wait: float = 0.0


func _init(p_caption: String = "", p_color: Color = UiTheme.LIFE) -> void:
	caption = p_caption
	liquid_color = p_color
	custom_minimum_size = Vector2(150, 150)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_liquid = ColorRect.new()
	_liquid.name = "Liquid"
	_liquid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_liquid.offset_left = 10
	_liquid.offset_top = 10
	_liquid.offset_right = -10
	_liquid.offset_bottom = -10
	_liquid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"liquid_color", p_color)
	_liquid.material = material
	add_child(_liquid)
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)


func set_values(current: float, maximum: float) -> void:
	var old_fill := get_fill()
	value = maxf(current, 0.0)
	max_value = maxf(maximum, 0.001)
	var new_fill := get_fill()
	if new_fill < old_fill:
		_trail_wait = TRAIL_DELAY
		trail_fill = maxf(trail_fill, old_fill)
	tooltip_text = "%s: %d / %d" % [caption, roundi(value), roundi(max_value)]
	_frame.queue_redraw()


func get_fill() -> float:
	return clampf(value / max_value, 0.0, 1.0)


func _process(delta: float) -> void:
	var target := get_fill()
	displayed_fill = move_toward(displayed_fill, target, delta * 1.5)
	displayed_fill = lerpf(displayed_fill, target, 1.0 - exp(-10.0 * delta))
	if _trail_wait > 0.0:
		_trail_wait -= delta
	else:
		trail_fill = move_toward(trail_fill, displayed_fill, delta * 0.6)
	trail_fill = maxf(trail_fill, displayed_fill)
	var material := _liquid.material as ShaderMaterial
	material.set_shader_parameter(&"fill", displayed_fill)
	material.set_shader_parameter(&"trail", trail_fill)


func _draw_frame() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 6.0
	_frame.draw_arc(center, radius + 2.0, 0.0, TAU, 64, Color(0, 0, 0, 0.9), 7.0, true)
	_frame.draw_arc(center, radius, 0.0, TAU, 64, UiTheme.BORDER, 4.0, true)
	_frame.draw_arc(center, radius - 3.0, PI * 1.1, PI * 1.9, 24, UiTheme.BORDER_BRIGHT, 1.5, true)
	var font := get_theme_default_font()
	var text := "%d / %d" % [roundi(value), roundi(max_value)]
	var pos := Vector2(0, center.y + 6)
	_frame.draw_string_outline(
		font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FONT_SIZE, 4, Color.BLACK
	)
	_frame.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FONT_SIZE)
