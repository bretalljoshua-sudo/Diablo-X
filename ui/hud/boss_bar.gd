class_name BossBar
extends Control
## Großer Lebensbalken oben in der Mitte während eines Bosskampfs. Start und Ende über
## EventBus.boss_encounter_started/_ended (AP9), Leben über entity_health_changed,
## Phase über boss_phase_changed. Markierung bei 50 % für den Phasenwechsel.

const PHASE_MARKS: Array[float] = [0.5]

var boss: Node3D
var boss_name: String = ""
var current: float = 1.0
var maximum: float = 1.0
var phase: int = 1
var displayed: float = 1.0
var trail: float = 1.0


func _init() -> void:
	name = "BossBar"
	custom_minimum_size = Vector2(720, 58)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	EventBus.boss_encounter_started.connect(start)
	EventBus.boss_encounter_ended.connect(_on_ended)
	EventBus.entity_health_changed.connect(_on_health_changed)
	EventBus.boss_phase_changed.connect(_on_phase_changed)
	EventBus.entity_died.connect(func(entity: Node3D, _killer: Node3D) -> void: _on_ended(entity))


func start(p_boss: Node3D, p_name: String) -> void:
	boss = p_boss
	boss_name = p_name
	phase = 1
	current = 1.0
	maximum = 1.0
	displayed = 1.0
	trail = 1.0
	visible = true
	queue_redraw()


func get_ratio() -> float:
	return clampf(current / maxf(maximum, 0.001), 0.0, 1.0)


func _on_ended(p_boss: Node3D) -> void:
	if p_boss == boss:
		boss = null
		visible = false


func _on_health_changed(entity: Node3D, p_current: float, p_maximum: float) -> void:
	if entity == null or entity != boss:
		return
	current = p_current
	maximum = p_maximum
	queue_redraw()


func _on_phase_changed(p_boss: Node3D, p_phase: int) -> void:
	if p_boss == boss:
		phase = p_phase
		queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	if boss != null and not is_instance_valid(boss):
		boss = null
		visible = false
		return
	var target := get_ratio()
	displayed = lerpf(displayed, target, 1.0 - exp(-12.0 * delta))
	trail = maxf(move_toward(trail, displayed, delta * 0.35), displayed)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var title := boss_name if phase <= 1 else "%s · Phase %d" % [boss_name, phase]
	draw_string_outline(
		font, Vector2(0, 20), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, 5, Color.BLACK
	)
	draw_string(
		font, Vector2(0, 20), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, UiTheme.TEXT_TITLE
	)
	var bar := Rect2(Vector2(0, 30), Vector2(size.x, 22))
	draw_rect(bar.grow(3.0), Color(0, 0, 0, 0.9))
	draw_rect(bar, Color(0.08, 0.02, 0.02))
	var inner := bar.grow(-2.0)
	draw_rect(
		Rect2(inner.position, Vector2(inner.size.x * trail, inner.size.y)), Color(0.9, 0.75, 0.6)
	)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * displayed, inner.size.y)), UiTheme.LIFE)
	draw_rect(
		Rect2(inner.position, Vector2(inner.size.x * displayed, 4)), UiTheme.LIFE.lightened(0.35)
	)
	for mark in PHASE_MARKS:
		var x := inner.position.x + inner.size.x * mark
		draw_line(Vector2(x, bar.position.y - 3), Vector2(x, bar.end.y + 3), UiTheme.GOLD, 2.0)
	draw_rect(bar, UiTheme.BORDER_BRIGHT, false, 2.0)
