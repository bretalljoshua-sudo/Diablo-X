class_name Inventory
extends Node
## Rucksack als Raster plus Gold. Hängt als Komponente an der Spielerfigur (AP2),
## das Inventar-Fenster (AP7) zeigt es an.
##
## Jeder Gegenstand belegt base.grid_size Zellen ab seiner linken oberen Ecke.

signal changed

const INVALID_CELL := Vector2i(-1, -1)

@export var width: int = 10
@export var height: int = 6

var gold: int = 0

## Gegenstand → linke obere Zelle.
var _positions: Dictionary[ItemInstance, Vector2i] = {}
## Belegte Zelle → Gegenstand.
var _cells: Dictionary[Vector2i, ItemInstance] = {}


## Das Inventar einer Figur (direktes Kind vom Typ Inventory), sonst null.
static func find_on(owner_node: Node) -> Inventory:
	if owner_node == null:
		return null
	for child in owner_node.get_children():
		if child is Inventory:
			return child
	return null


static func size_of(item: ItemInstance) -> Vector2i:
	if item == null or item.base == null:
		return Vector2i.ONE
	return Vector2i(maxi(item.base.grid_size.x, 1), maxi(item.base.grid_size.y, 1))


func get_items() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	result.assign(_positions.keys())
	return result


func has_item(item: ItemInstance) -> bool:
	return _positions.has(item)


func get_item_count() -> int:
	return _positions.size()


## Linke obere Zelle eines Gegenstands, INVALID_CELL wenn er nicht im Inventar ist.
func get_position_of(item: ItemInstance) -> Vector2i:
	return _positions.get(item, INVALID_CELL)


func get_item_at(cell: Vector2i) -> ItemInstance:
	return _cells.get(cell, null)


## Passt der Gegenstand mit der linken oberen Ecke auf cell? ignore darf dabei überdeckt werden
## (zum Verschieben innerhalb des Inventars).
func can_place(item: ItemInstance, cell: Vector2i, ignore: ItemInstance = null) -> bool:
	var size := size_of(item)
	if cell.x < 0 or cell.y < 0 or cell.x + size.x > width or cell.y + size.y > height:
		return false
	for x in range(cell.x, cell.x + size.x):
		for y in range(cell.y, cell.y + size.y):
			var other: ItemInstance = _cells.get(Vector2i(x, y), null)
			if other != null and other != ignore:
				return false
	return true


## Erste freie Stelle (spaltenweise von links oben), INVALID_CELL wenn keine.
func find_space(item: ItemInstance) -> Vector2i:
	for x in width:
		for y in height:
			if can_place(item, Vector2i(x, y)):
				return Vector2i(x, y)
	return INVALID_CELL


func has_space_for(item: ItemInstance) -> bool:
	return find_space(item) != INVALID_CELL


## Legt den Gegenstand an die erste freie Stelle. false, wenn kein Platz ist.
func add_item(item: ItemInstance) -> bool:
	if item == null or has_item(item):
		return false
	var cell := find_space(item)
	if cell == INVALID_CELL:
		return false
	_occupy(item, cell)
	changed.emit()
	return true


## Legt den Gegenstand an eine bestimmte Stelle.
func place_item(item: ItemInstance, cell: Vector2i) -> bool:
	if item == null or has_item(item) or not can_place(item, cell):
		return false
	_occupy(item, cell)
	changed.emit()
	return true


## Verschiebt einen Gegenstand innerhalb des Inventars.
func move_item(item: ItemInstance, cell: Vector2i) -> bool:
	if not has_item(item) or not can_place(item, cell, item):
		return false
	_release(item)
	_occupy(item, cell)
	changed.emit()
	return true


func remove_item(item: ItemInstance) -> bool:
	if not has_item(item):
		return false
	_release(item)
	changed.emit()
	return true


## Aufsammeln vom Boden: ins Inventar legen und EventBus.loot_picked_up senden.
func pick_up(item: ItemInstance) -> bool:
	if not add_item(item):
		return false
	EventBus.loot_picked_up.emit(item)
	return true


## Ändert das Gold und sendet EventBus.gold_changed. Negative Beträge nur über spend_gold().
func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	EventBus.gold_changed.emit(gold, amount)
	changed.emit()


## Zieht Gold ab. false (und keine Änderung), wenn nicht genug da ist.
func spend_gold(amount: int) -> bool:
	if amount < 0 or amount > gold:
		return false
	if amount == 0:
		return true
	gold -= amount
	EventBus.gold_changed.emit(gold, -amount)
	changed.emit()
	return true


## Verkauft einen Gegenstand aus dem Inventar und liefert den Erlös (0, wenn er nicht da ist).
func sell_item(item: ItemInstance) -> int:
	if not remove_item(item):
		return 0
	var value := ItemValue.sell_value(item)
	add_gold(value)
	return value


func clear() -> void:
	_positions.clear()
	_cells.clear()
	changed.emit()


func _occupy(item: ItemInstance, cell: Vector2i) -> void:
	var size := size_of(item)
	_positions[item] = cell
	for x in range(cell.x, cell.x + size.x):
		for y in range(cell.y, cell.y + size.y):
			_cells[Vector2i(x, y)] = item


func _release(item: ItemInstance) -> void:
	var cell: Vector2i = _positions[item]
	var size := size_of(item)
	for x in range(cell.x, cell.x + size.x):
		for y in range(cell.y, cell.y + size.y):
			_cells.erase(Vector2i(x, y))
	_positions.erase(item)
