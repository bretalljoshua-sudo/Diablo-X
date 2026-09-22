class_name ExperienceBar
extends Control
## Erfahrungsbalken über der Skillleiste, in zehn Abschnitte geteilt.
## Hört auf EventBus.experience_changed und player_level_up (AP5).

var current: int = 0
var required: int = 1
var level: int = 1


func _init() -> void:
	name = "ExperienceBar"
	custom_minimum_size = Vector2(420, 12)
	mouse_filter = Control.MOUSE_FILTER_PASS
	EventBus.experience_changed.connect(set_experience)
	EventBus.player_level_up.connect(
		func(p_level: int) -> void: set_experience(0, required, p_level)
	)
	_update_tooltip()


func set_experience(p_current: int, p_required: int, p_level: int) -> void:
	current = maxi(p_current, 0)
	required = maxi(p_required, 1)
	level = p_level
	_update_tooltip()
	queue_redraw()


func get_ratio() -> float:
	return clampf(float(current) / float(required), 0.0, 1.0)


func _update_tooltip() -> void:
	tooltip_text = "Stufe %d · %d / %d Erfahrung" % [level, current, required]


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.02, 0.02, 0.02, 0.9))
	var fill := Rect2(
		rect.position + Vector2(1, 1), Vector2((rect.size.x - 2) * get_ratio(), rect.size.y - 2)
	)
	draw_rect(fill, UiTheme.EXPERIENCE)
	draw_rect(Rect2(fill.position, Vector2(fill.size.x, 2)), UiTheme.EXPERIENCE.lightened(0.4))
	for i in range(1, 10):
		var x := rect.size.x * i / 10.0
		draw_line(Vector2(x, 1), Vector2(x, rect.size.y - 1), Color(0, 0, 0, 0.7), 1.0)
	draw_rect(rect, UiTheme.BORDER, false, 1.0)
