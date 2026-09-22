class_name PotionDisplay
extends Control
## Heiltrank neben der Lebenskugel: Flasche, Anzahl der Ladungen und Fortschritt zur nächsten
## Ladung. Hört auf EventBus.potion_charges_changed (AP2).

var charges: int = 0
var maximum: int = 0
var progress: float = 0.0


func _init() -> void:
	name = "PotionDisplay"
	custom_minimum_size = Vector2(52, 72)
	mouse_filter = Control.MOUSE_FILTER_PASS
	EventBus.potion_charges_changed.connect(set_charges)


func set_charges(p_charges: int, p_maximum: int, p_progress: float) -> void:
	charges = p_charges
	maximum = p_maximum
	progress = clampf(p_progress, 0.0, 1.0)
	tooltip_text = "Heiltrank: %d von %d Ladungen" % [charges, maximum]
	queue_redraw()


func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.58)
	var radius := size.x * 0.36
	var neck := Rect2(center.x - 6, center.y - radius - 14, 12, 16)
	var liquid := UiTheme.LIFE if charges > 0 else Color(0.25, 0.08, 0.08)
	draw_circle(center, radius + 2.0, Color(0, 0, 0, 0.85))
	draw_circle(center, radius, Color(0.05, 0.03, 0.03))
	if charges > 0:
		draw_circle(center, radius - 3.0, liquid)
	elif progress > 0.0:
		# Füllt sich von unten, solange die nächste Ladung lädt.
		var points := PackedVector2Array()
		var level := center.y + radius - progress * radius * 2.0
		for i in 33:
			var angle := TAU * i / 32.0
			var p := center + Vector2(cos(angle), sin(angle)) * (radius - 3.0)
			points.append(Vector2(p.x, maxf(p.y, level)))
		draw_colored_polygon(points, liquid.darkened(0.2))
	draw_rect(neck, Color(0.12, 0.1, 0.09))
	draw_rect(neck, UiTheme.BORDER, false, 1.5)
	draw_arc(center, radius, 0.0, TAU, 40, UiTheme.BORDER, 2.0, true)
	draw_circle(
		center + Vector2(-radius * 0.35, -radius * 0.35), radius * 0.18, Color(1, 1, 1, 0.25)
	)
	var font := get_theme_default_font()
	var text := str(charges)
	draw_string_outline(
		font, center + Vector2(-20, 7), text, HORIZONTAL_ALIGNMENT_CENTER, 40, 18, 4, Color.BLACK
	)
	draw_string(font, center + Vector2(-20, 7), text, HORIZONTAL_ALIGNMENT_CENTER, 40, 18)
	var key := Settings.get_key_binding(&"potion")
	draw_string(
		font,
		Vector2(0, size.y - 1),
		OS.get_keycode_string(key) if key != KEY_NONE else "",
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		11,
		UiTheme.TEXT_TITLE
	)
