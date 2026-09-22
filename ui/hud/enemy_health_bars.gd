class_name EnemyHealthBars
extends Control
## Kleine Lebensbalken über Gegnern. Ein Balken erscheint, sobald ein Gegner Schaden hat oder
## unter der Maus ist (dann mit Namen), und verschwindet beim Tod.
## Daten: EventBus.entity_health_changed (AP2), hovered_target_changed (AP2), entity_died.
## Optional am Gegner: Eigenschaft display_name (String) und is_elite (bool), sonst Knotenname.

const BAR_SIZE := Vector2(78, 7)
## Höhe über dem Ursprung der Figur in Metern.
const HEAD_HEIGHT := 2.3
## Nach so vielen Sekunden ohne Änderung blendet ein voller Balken aus.
const HIDE_AFTER := 3.0

## Figur → {current, maximum, age}
var entries: Dictionary[Node3D, Dictionary] = {}
var hovered: Node3D
## Bosse haben ihren eigenen Balken (BossBar).
var excluded: Array[Node3D] = []


func _init() -> void:
	name = "EnemyHealthBars"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	EventBus.entity_health_changed.connect(set_health)
	EventBus.hovered_target_changed.connect(_on_hovered)
	EventBus.entity_died.connect(func(entity: Node3D, _killer: Node3D) -> void: remove(entity))
	EventBus.boss_encounter_started.connect(_on_boss_started)
	EventBus.boss_encounter_ended.connect(func(boss: Node3D) -> void: excluded.erase(boss))


func set_health(entity: Node3D, current: float, maximum: float) -> void:
	if entity == null or entity == Game.player or entity in excluded:
		return
	entries[entity] = {"current": current, "maximum": maxf(maximum, 0.001), "age": 0.0}
	queue_redraw()


func remove(entity: Node3D) -> void:
	entries.erase(entity)
	if hovered == entity:
		hovered = null
	queue_redraw()


func has_bar(entity: Node3D) -> bool:
	return entries.has(entity) and _is_shown(entity)


static func display_name_of(entity: Node) -> String:
	if entity == null:
		return ""
	var value: Variant = entity.get(&"display_name")
	if value is String and not (value as String).is_empty():
		return value
	return String(entity.name)


func _on_boss_started(boss: Node3D, _boss_name: String) -> void:
	excluded.append(boss)
	entries.erase(boss)


func _on_hovered(target: Node3D) -> void:
	hovered = target if target != Game.player else null
	queue_redraw()


func _is_shown(entity: Node3D) -> bool:
	var entry: Dictionary = entries.get(entity, {})
	if entity == hovered:
		return true
	if entry.is_empty():
		return false
	return entry["current"] < entry["maximum"] or entry["age"] < HIDE_AFTER


func _process(delta: float) -> void:
	for entity: Node3D in entries.keys():
		if not is_instance_valid(entity) or not entity.is_inside_tree():
			entries.erase(entity)
			continue
		entries[entity]["age"] += delta
	if hovered != null and not is_instance_valid(hovered):
		hovered = null
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var shown: Array[Node3D] = []
	shown.assign(entries.keys())
	if hovered != null and not hovered in shown and not hovered in excluded:
		shown.append(hovered)
	var font := get_theme_default_font()
	for entity in shown:
		if not is_instance_valid(entity) or not _is_shown(entity):
			continue
		var world := entity.global_position + Vector3.UP * HEAD_HEIGHT
		if camera.is_position_behind(world):
			continue
		var screen := camera.unproject_position(world)
		var entry: Dictionary = entries.get(entity, {"current": 1.0, "maximum": 1.0})
		var ratio := clampf(entry["current"] / entry["maximum"], 0.0, 1.0)
		var elite: bool = entity.get(&"is_elite") == true
		var rect := Rect2(screen - Vector2(BAR_SIZE.x * 0.5, 0), BAR_SIZE)
		draw_rect(rect.grow(2.0), Color(0, 0, 0, 0.85))
		draw_rect(rect, Color(0.12, 0.02, 0.02))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), UiTheme.LIFE)
		if elite:
			draw_rect(rect.grow(2.0), UiTheme.GOLD, false, 1.5)
		if entity == hovered:
			var label := display_name_of(entity)
			var color := UiTheme.GOLD if elite else UiTheme.TEXT
			var pos := Vector2(screen.x - 150, rect.position.y - 6)
			draw_string_outline(
				font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, 300, 15, 4, Color.BLACK
			)
			draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, 300, 15, color)
