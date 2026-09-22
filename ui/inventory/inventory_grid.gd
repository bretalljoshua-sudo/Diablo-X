class_name InventoryGrid
extends Control
## Zeigt das Raster eines Inventory (AP4) und bedient es mit Maus und Tastatur.
##
## Maus: Linksklick nimmt einen Gegenstand auf, zweiter Linksklick legt ihn ab (verschieben).
##       Rechtsklick aktiviert ihn (Anlegen, beim Händler Verkaufen).
## Tastatur: Pfeiltasten bewegen die Auswahl, Enter aktiviert, Leertaste nimmt auf und legt ab.

signal item_hovered(item: ItemInstance, global_rect: Rect2)
signal hover_cleared
## Rechtsklick oder Enter auf einem Gegenstand.
signal item_activated(item: ItemInstance)
signal held_item_changed(item: ItemInstance)

const CELL := 50.0
const INVALID := Vector2i(-1, -1)

var inventory: Inventory
## Gegenstand, der gerade verschoben wird (bleibt bis zum Ablegen an seinem Platz im Inventar).
var held_item: ItemInstance
## Auswahl für die Tastatur.
var selected_cell: Vector2i = Vector2i.ZERO

var _hover_cell: Vector2i = INVALID
var _hovered_item: ItemInstance


func _init() -> void:
	name = "InventoryGrid"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_inventory(p_inventory: Inventory) -> void:
	if inventory != null and inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.disconnect(_on_inventory_changed)
	inventory = p_inventory
	held_item = null
	if inventory != null:
		inventory.changed.connect(_on_inventory_changed)
	update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	if inventory == null:
		return Vector2(10, 6) * CELL
	return Vector2(inventory.width, inventory.height) * CELL


## Zelle unter einer lokalen Position, INVALID außerhalb.
func cell_at(local_pos: Vector2) -> Vector2i:
	if inventory == null:
		return INVALID
	var cell := Vector2i(floori(local_pos.x / CELL), floori(local_pos.y / CELL))
	if cell.x < 0 or cell.y < 0 or cell.x >= inventory.width or cell.y >= inventory.height:
		return INVALID
	return cell


func cell_rect(cell: Vector2i, cells: Vector2i = Vector2i.ONE) -> Rect2:
	return Rect2(Vector2(cell) * CELL, Vector2(cells) * CELL)


## Globale Mitte einer Zelle (für Simulationstests und Tooltips).
func cell_global_center(cell: Vector2i) -> Vector2:
	return get_global_transform() * (cell_rect(cell).get_center())


func item_global_rect(item: ItemInstance) -> Rect2:
	if inventory == null or not inventory.has_item(item):
		return Rect2()
	var local := cell_rect(inventory.get_position_of(item), Inventory.size_of(item))
	return Rect2(get_global_transform() * local.position, local.size)


func pick_up(item: ItemInstance) -> void:
	if item == held_item:
		return
	held_item = item
	held_item_changed.emit(held_item)
	queue_redraw()


func cancel_hold() -> void:
	if held_item == null:
		return
	held_item = null
	held_item_changed.emit(null)
	queue_redraw()


## Legt den gehaltenen Gegenstand mit der linken oberen Ecke auf cell ab.
func drop_held_at(cell: Vector2i) -> bool:
	if held_item == null or inventory == null:
		return false
	if not inventory.has_item(held_item):
		cancel_hold()
		return false
	if inventory.get_position_of(held_item) == cell:
		cancel_hold()
		return true
	if not inventory.move_item(held_item, cell):
		return false
	cancel_hold()
	return true


func _gui_input(event: InputEvent) -> void:
	if inventory == null:
		return
	if event is InputEventMouseMotion:
		_set_hover_cell(cell_at((event as InputEventMouseMotion).position))
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button := event as InputEventMouseButton
		var cell := cell_at(button.position)
		_set_hover_cell(cell)
		if cell == INVALID:
			return
		selected_cell = cell
		if button.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click(cell)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			if held_item != null:
				cancel_hold()
			else:
				var item := inventory.get_item_at(cell)
				if item != null:
					item_activated.emit(item)
			accept_event()
	elif event is InputEventKey or event is InputEventAction:
		_handle_key(event)


func _handle_key(event: InputEvent) -> void:
	var step := Vector2i.ZERO
	if event.is_action_pressed(&"ui_left", true):
		step = Vector2i.LEFT
	elif event.is_action_pressed(&"ui_right", true):
		step = Vector2i.RIGHT
	elif event.is_action_pressed(&"ui_up", true):
		step = Vector2i.UP
	elif event.is_action_pressed(&"ui_down", true):
		step = Vector2i.DOWN
	elif event.is_action_pressed(&"ui_accept"):
		if held_item != null:
			drop_held_at(selected_cell)
		else:
			var item := inventory.get_item_at(selected_cell)
			if item != null:
				item_activated.emit(item)
		accept_event()
		return
	elif event.is_action_pressed(&"ui_select"):
		_on_left_click(selected_cell)
		accept_event()
		return
	else:
		return
	var next := selected_cell + step
	if next.x < 0 or next.y < 0 or next.x >= inventory.width or next.y >= inventory.height:
		# Am Rand den Fokus an den Nachbarn abgeben (zum Beispiel an die Ausrüstung).
		return
	selected_cell = next
	_emit_hover_for(selected_cell)
	queue_redraw()
	accept_event()


func _on_left_click(cell: Vector2i) -> void:
	if held_item != null:
		drop_held_at(cell)
		return
	var item := inventory.get_item_at(cell)
	if item != null:
		pick_up(item)


func _set_hover_cell(cell: Vector2i) -> void:
	if cell == _hover_cell:
		return
	_hover_cell = cell
	_emit_hover_for(cell)
	queue_redraw()


func _emit_hover_for(cell: Vector2i) -> void:
	var item := inventory.get_item_at(cell) if cell != INVALID and inventory != null else null
	if item == _hovered_item:
		return
	_hovered_item = item
	if item != null:
		item_hovered.emit(item, item_global_rect(item))
	else:
		hover_cleared.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_cell = INVALID
		if _hovered_item != null:
			_hovered_item = null
			hover_cleared.emit()
		queue_redraw()
	elif what == NOTIFICATION_FOCUS_ENTER:
		_emit_hover_for(selected_cell)
		queue_redraw()
	elif what == NOTIFICATION_FOCUS_EXIT:
		if _hovered_item != null and _hover_cell == INVALID:
			_hovered_item = null
			hover_cleared.emit()
		queue_redraw()


func _on_inventory_changed() -> void:
	if held_item != null and not inventory.has_item(held_item):
		cancel_hold()
	_hovered_item = null
	queue_redraw()


func _draw() -> void:
	if inventory == null:
		return
	var line := Color(UiTheme.BORDER, 0.35)
	draw_rect(Rect2(Vector2.ZERO, _get_minimum_size()), UiTheme.SLOT_BACKGROUND)
	for x in inventory.width:
		for y in inventory.height:
			draw_rect(cell_rect(Vector2i(x, y)).grow(-1.0), line, false, 1.0)
	for item in inventory.get_items():
		var rect := cell_rect(inventory.get_position_of(item), Inventory.size_of(item))
		ItemIcon.draw(self, rect.grow(-1.0), item, item == held_item)
	if _hover_cell != INVALID and held_item == null:
		var hovered := inventory.get_item_at(_hover_cell)
		if hovered != null:
			var rect := cell_rect(inventory.get_position_of(hovered), Inventory.size_of(hovered))
			draw_rect(rect.grow(-1.0), UiTheme.HIGHLIGHT)
	if held_item != null:
		var target := _hover_cell if _hover_cell != INVALID else selected_cell
		var size := Inventory.size_of(held_item)
		var ok := inventory.can_place(held_item, target, held_item)
		var rect := cell_rect(target, size)
		ItemIcon.draw(self, rect.grow(-1.0), held_item)
		draw_rect(rect.grow(-1.0), UiTheme.BETTER if ok else UiTheme.WORSE, false, 2.0)
	if has_focus():
		draw_rect(cell_rect(selected_cell).grow(-2.0), UiTheme.BORDER_BRIGHT, false, 2.0)
