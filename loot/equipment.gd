class_name Equipment
extends Node
## Angelegte Gegenstände der Spielerfigur. Hängt als Komponente an der Figur (AP2).
##
## get_bonus_stats() ist die Summe aller angelegten Gegenstände; AP2 rechnet sie im
## Stats-Dienst zu den Grundwerten. Nach jeder Änderung kommt stats_changed.
## Ablegen sendet EventBus.player_equipped(slot, null).

signal stats_changed

var _items: Dictionary[Enums.Slot, ItemInstance] = {}
var _bonus_cache: StatBlock


## Die Ausrüstung einer Figur (direktes Kind vom Typ Equipment), sonst null.
static func find_on(owner_node: Node) -> Equipment:
	if owner_node == null:
		return null
	for child in owner_node.get_children():
		if child is Equipment:
			return child
	return null


## Plätze, in die ein Gegenstand passt (Ringe in beide Ringplätze).
static func slots_for(item: ItemInstance) -> Array[Enums.Slot]:
	var result: Array[Enums.Slot] = []
	if item == null or item.base == null:
		return result
	for slot: Enums.Slot in Enums.Slot.values():
		if ItemDatabase.slot_matches(item.base.slot, slot):
			result.append(slot)
	return result


func can_equip(item: ItemInstance, slot: Enums.Slot) -> bool:
	return slot in slots_for(item)


func get_item(slot: Enums.Slot) -> ItemInstance:
	return _items.get(slot, null)


func get_equipped() -> Dictionary[Enums.Slot, ItemInstance]:
	return _items.duplicate()


func is_equipped(item: ItemInstance) -> bool:
	return item != null and item in _items.values()


## Legt einen Gegenstand an und liefert den vorher angelegten (oder null).
## slot = -1 wählt selbst: einen freien passenden Platz, sonst den ersten passenden.
## Passt der Gegenstand nicht, bleibt alles unverändert und das Ergebnis ist item selbst.
func equip(item: ItemInstance, slot: int = -1) -> ItemInstance:
	var target := slot if slot >= 0 else choose_slot(item)
	if target < 0 or not can_equip(item, target as Enums.Slot) or is_equipped(item):
		return item
	var previous: ItemInstance = _items.get(target, null)
	_items[target as Enums.Slot] = item
	_on_changed()
	EventBus.player_equipped.emit(target as Enums.Slot, item)
	return previous


## Nimmt den Gegenstand eines Platzes ab und liefert ihn (oder null).
func unequip(slot: Enums.Slot) -> ItemInstance:
	if not _items.has(slot):
		return null
	var previous: ItemInstance = _items[slot]
	_items.erase(slot)
	_on_changed()
	EventBus.player_equipped.emit(slot, null)
	return previous


## Platz, den equip() ohne Angabe wählen würde, -1 wenn keiner passt.
func choose_slot(item: ItemInstance) -> int:
	var slots := slots_for(item)
	if slots.is_empty():
		return -1
	for slot in slots:
		if not _items.has(slot):
			return slot
	# Alle belegt: bei Ringen den schwächeren ersetzen.
	var weakest := slots[0]
	for slot in slots:
		if ItemCompare.score(_items[slot]) < ItemCompare.score(_items[weakest]):
			weakest = slot
	return weakest


## Legt einen Gegenstand aus dem Inventar an. Der vorher angelegte wandert ins Inventar,
## möglichst an die frei gewordene Stelle. false (und keine Änderung), wenn es nicht geht.
func equip_from_inventory(inventory: Inventory, item: ItemInstance, slot: int = -1) -> bool:
	if inventory == null or not inventory.has_item(item):
		return false
	var target := slot if slot >= 0 else choose_slot(item)
	if target < 0 or not can_equip(item, target as Enums.Slot):
		return false
	var cell := inventory.get_position_of(item)
	inventory.remove_item(item)
	var previous := equip(item, target)
	if previous != null:
		if not inventory.place_item(previous, cell) and not inventory.add_item(previous):
			# Kein Platz für den alten Gegenstand: alles zurück.
			equip(previous, target)
			inventory.place_item(item, cell)
			return false
	return true


## Nimmt einen Gegenstand ab und legt ihn ins Inventar. false, wenn dort kein Platz ist.
func unequip_to_inventory(inventory: Inventory, slot: Enums.Slot) -> bool:
	var item := get_item(slot)
	if item == null or inventory == null or not inventory.has_space_for(item):
		return false
	unequip(slot)
	inventory.add_item(item)
	return true


## Summe der Werte aller angelegten Gegenstände.
func get_bonus_stats() -> StatBlock:
	if _bonus_cache == null:
		_bonus_cache = StatBlock.new()
		for item: ItemInstance in _items.values():
			_bonus_cache.add(item.get_stats())
	var copy := StatBlock.new()
	copy.add(_bonus_cache)
	return copy


## Grundwerte plus Ausrüstung, als neuer Block.
func apply_to(base_stats: StatBlock) -> StatBlock:
	var result := StatBlock.new()
	result.add(base_stats)
	result.add(get_bonus_stats())
	return result


## Aspekte und einzigartige Kräfte aller angelegten Gegenstände.
func get_aspects() -> Array[AspectDef]:
	var result: Array[AspectDef] = []
	for item: ItemInstance in _items.values():
		if item.aspect != null and not item.aspect in result:
			result.append(item.aspect)
	return result


## Aspekte, die einen Skill mit diesen Tags verändern (für AP5).
func get_aspects_for_tags(tags: Array[StringName]) -> Array[AspectDef]:
	var result: Array[AspectDef] = []
	for aspect in get_aspects():
		for tag in aspect.skill_tags:
			if tag in tags:
				result.append(aspect)
				break
	return result


func clear() -> void:
	_items.clear()
	_on_changed()


func _on_changed() -> void:
	_bonus_cache = null
	stats_changed.emit()
