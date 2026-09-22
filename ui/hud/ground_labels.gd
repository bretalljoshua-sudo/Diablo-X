class_name GroundLabels
extends Control
## Beschriftungen für Beute am Boden, solange Alt (Aktion show_item_labels) gehalten wird.
## Farbe nach Seltenheit, überlappende Schilder rutschen untereinander. Klick auf ein Schild hebt
## den Gegenstand auf (Inventar von Game.player), Überfahren zeigt den Tooltip mit Vergleich.
## Quelle: alle GroundItem-Knoten in der Gruppe GroundItem.GROUP (AP4).

## Höhe des Schilds über dem Gegenstand in Metern.
const LABEL_HEIGHT := 0.7
const PADDING := Vector2(10, 4)

var tooltip: ItemTooltip
## Immer zeigen (zum Beispiel für Tests); sonst nur mit gehaltener Alt-Taste.
var force_visible: bool = false
## Gezeigte Schilder: GroundItem → Rechteck in Bildschirmkoordinaten.
var label_rects: Dictionary[GroundItem, Rect2] = {}

var _hovered: GroundItem


func _init() -> void:
	name = "GroundLabels"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func is_active() -> bool:
	return force_visible or Input.is_action_pressed(&"show_item_labels")


## Hebt den Gegenstand hinter einem Schild auf. false, wenn kein Platz ist.
func pick_up(ground: GroundItem) -> bool:
	if ground == null or not is_instance_valid(ground):
		return false
	var ok := ground.try_pick_up(Inventory.find_on(Game.player))
	if ok:
		label_rects.erase(ground)
		_set_hovered(null)
	return ok


func label_at(screen_pos: Vector2) -> GroundItem:
	for ground: GroundItem in label_rects:
		if label_rects[ground].has_point(screen_pos) and is_instance_valid(ground):
			return ground
	return null


func _process(_delta: float) -> void:
	var active := is_active()
	# Klicks nur abfangen, solange Schilder zu sehen sind.
	mouse_filter = Control.MOUSE_FILTER_PASS if active else Control.MOUSE_FILTER_IGNORE
	if active:
		_layout_labels()
	elif not label_rects.is_empty():
		label_rects.clear()
		_set_hovered(null)
	queue_redraw()


func _has_point(point: Vector2) -> bool:
	return is_active() and label_at(point) != null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hovered(label_at((event as InputEventMouseMotion).position))
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			var ground := label_at(button.position)
			if ground != null:
				pick_up(ground)
				accept_event()


func _set_hovered(ground: GroundItem) -> void:
	if ground == _hovered:
		return
	_hovered = ground
	if tooltip == null:
		return
	if ground == null or ground.item == null:
		tooltip.hide_tooltip()
		return
	var equipment := Equipment.find_on(Game.player)
	var current: ItemInstance = null
	var slot := equipment.choose_slot(ground.item) if equipment != null else -1
	if slot >= 0:
		current = equipment.get_item(slot as Enums.Slot)
	var rect: Rect2 = label_rects.get(ground, Rect2())
	tooltip.show_item(
		ground.item,
		Rect2(get_global_transform() * rect.position, rect.size),
		current,
		slot >= 0,
		"Klick: Aufheben"
	)


func _layout_labels() -> void:
	label_rects.clear()
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var font := get_theme_default_font()
	var entries: Array[Array] = []
	for node in get_tree().get_nodes_in_group(GroundItem.GROUP):
		var ground := node as GroundItem
		if ground == null or ground.is_queued_for_deletion() or not ground.is_inside_tree():
			continue
		var world := ground.global_position + Vector3.UP * LABEL_HEIGHT
		if camera.is_position_behind(world):
			continue
		var screen := camera.unproject_position(world)
		var text_size := font.get_string_size(
			_text_of(ground), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE
		)
		# Mittig auf dem Namensschild des GroundItem, damit es verdeckt wird.
		var rect := Rect2(
			screen - Vector2(text_size.x * 0.5 + PADDING.x, text_size.y * 0.5 + PADDING.y),
			text_size + PADDING * 2.0
		)
		entries.append([ground, rect])
	entries.sort_custom(
		func(a: Array, b: Array) -> bool:
			return (a[1] as Rect2).position.y < (b[1] as Rect2).position.y
	)
	var placed: Array[Rect2] = []
	for entry in entries:
		var rect: Rect2 = entry[1]
		var moved := true
		while moved:
			moved = false
			for other in placed:
				if other.intersects(rect):
					rect.position.y = other.end.y + 1.0
					moved = true
		placed.append(rect)
		label_rects[entry[0]] = rect


static func _text_of(ground: GroundItem) -> String:
	if ground.item != null:
		return ground.item.get_display_name()
	return "%d Gold" % ground.gold


func _draw() -> void:
	if label_rects.is_empty():
		return
	var font := get_theme_default_font()
	for ground: GroundItem in label_rects:
		if not is_instance_valid(ground):
			continue
		var rect := label_rects[ground]
		var color := GroundItem.GOLD_COLOR
		if ground.item != null:
			color = ItemText.rarity_color(ground.item.rarity)
		draw_rect(rect, Color(0.02, 0.02, 0.02, 0.97))
		var border := color if ground == _hovered else Color(color, 0.5)
		draw_rect(rect, border, false, 1.0)
		draw_string(
			font,
			rect.position + Vector2(PADDING.x, rect.size.y - PADDING.y - 3),
			_text_of(ground),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			UiTheme.FONT_SIZE,
			color
		)
