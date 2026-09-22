class_name SkillSlot
extends Control
## Ein Platz der Skillleiste: Symbol, Taste, Abklingzeit als dunkler Kreisausschnitt mit
## Restsekunden, rot getönt bei zu wenig Wut, kurzes Aufleuchten beim Einsatz.

signal clicked

const SIZE := Vector2(64, 64)

var index: int = 0
var skill: SkillDef
var cooldown_total: float = 0.0
var cooldown_left: float = 0.0
var affordable: bool = true:
	set(value):
		if affordable != value:
			affordable = value
			queue_redraw()

var _flash: float = 0.0
var _flash_color: Color = Color(1.0, 0.9, 0.6)


func _init(p_index: int = 0) -> void:
	index = p_index
	name = "Slot%d" % p_index
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = SkillBar.SLOT_NAMES[p_index]


func set_skill(p_skill: SkillDef) -> void:
	skill = p_skill
	cooldown_left = 0.0
	tooltip_text = (
		"%s\n%s" % [p_skill.display_name, SkillBar.SLOT_NAMES[index]]
		if p_skill != null
		else SkillBar.SLOT_NAMES[index]
	)
	queue_redraw()


func start_cooldown(duration: float) -> void:
	cooldown_total = maxf(duration, 0.0)
	cooldown_left = cooldown_total
	queue_redraw()


func is_on_cooldown() -> bool:
	return cooldown_left > 0.0


func flash(color: Color = Color(1.0, 0.9, 0.6)) -> void:
	_flash = 1.0
	_flash_color = color
	queue_redraw()


func _process(delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(cooldown_left - delta, 0.0)
		if cooldown_left == 0.0:
			flash()
			_flash = 0.6
		queue_redraw()
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 3.0, 0.0)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var inner := rect.grow(-3.0)
	draw_rect(rect, Color(0, 0, 0, 0.85))
	if skill != null:
		if skill.icon != null:
			draw_texture_rect(skill.icon, inner, false)
		else:
			var base := SkillBar.category_color(skill)
			var colors := PackedColorArray(
				[base.darkened(0.45), base.darkened(0.45), base.darkened(0.8), base.darkened(0.8)]
			)
			var points := PackedVector2Array(
				[
					inner.position,
					Vector2(inner.end.x, inner.position.y),
					inner.end,
					Vector2(inner.position.x, inner.end.y)
				]
			)
			draw_polygon(points, colors)
			draw_string(
				get_theme_default_font(),
				Vector2(inner.position.x, inner.get_center().y + 9),
				SkillBar.initials(skill),
				HORIZONTAL_ALIGNMENT_CENTER,
				inner.size.x,
				24,
				UiTheme.TEXT
			)
		if not affordable:
			draw_rect(inner, Color(0.5, 0.0, 0.0, 0.45))
		if cooldown_left > 0.0 and cooldown_total > 0.0:
			_draw_cooldown(inner)
	draw_rect(rect, UiTheme.BORDER, false, 2.0)
	if _flash > 0.0:
		draw_rect(rect.grow(-1.0), Color(_flash_color, _flash * 0.8), false, 3.0)
	var key := SkillBar.key_label(index)
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2(2, size.y - 17), Vector2(22, 15)), Color(0, 0, 0, 0.75))
	draw_string(
		font, Vector2(2, size.y - 5), key, HORIZONTAL_ALIGNMENT_CENTER, 22, 11, UiTheme.TEXT_TITLE
	)


func _draw_cooldown(rect: Rect2) -> void:
	var ratio := cooldown_left / cooldown_total
	var center := rect.get_center()
	var radius := rect.size.length() * 0.5
	var steps := maxi(int(ratio * 48.0), 1)
	var shade := Color(0, 0, 0, 0.7)
	var previous := Vector2.ZERO
	for i in steps + 1:
		# Im Uhrzeigersinn ab 12 Uhr, der dunkle Teil schrumpft. Einzelne Dreiecke, damit auch
		# ein voller Kreis sauber gezeichnet wird.
		var angle := -PI * 0.5 + TAU * (1.0 - ratio) + TAU * ratio * float(i) / steps
		var point := _clip_to_rect(center, Vector2(cos(angle), sin(angle)) * radius, rect)
		if i > 0 and not point.is_equal_approx(previous):
			draw_colored_polygon(PackedVector2Array([center, previous, point]), shade)
		previous = point
	var seconds := (
		str(ceili(cooldown_left))
		if cooldown_left >= 1.0
		else ("%.1f" % cooldown_left).replace(".", ",")
	)
	draw_string(
		get_theme_default_font(),
		Vector2(rect.position.x, center.y + 8),
		seconds,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		22,
		Color.WHITE
	)


static func _clip_to_rect(center: Vector2, offset: Vector2, rect: Rect2) -> Vector2:
	var half := rect.size * 0.5
	var scale := 1.0
	if absf(offset.x) > half.x:
		scale = minf(scale, half.x / absf(offset.x))
	if absf(offset.y) > half.y:
		scale = minf(scale, half.y / absf(offset.y))
	return center + offset * scale
