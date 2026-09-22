class_name ItemSerializer
extends RefCounted
## Wandelt Gegenstände, Inventar und Ausrüstung in JSON-taugliche Dictionaries und zurück.
## Grundlage für den Spielstand (AP9). Inhalte werden über ihre id gespeichert, deshalb
## dürfen ids in data/ nicht umbenannt werden.


static func item_to_dict(item: ItemInstance) -> Dictionary:
	if item == null or item.base == null:
		return {}
	var affix_list: Array = []
	for roll in item.affixes:
		if roll != null and roll.affix != null:
			affix_list.append([String(roll.affix.id), roll.value])
	return {
		# Als Text, weil JSON große Ganzzahlen als Kommazahl ungenau speichert.
		"uid": str(item.uid),
		"base": String(item.base.id),
		"rarity": int(item.rarity),
		"level": item.item_level,
		"affixes": affix_list,
		"aspect": String(item.aspect.id) if item.aspect != null else "",
		"unique": item.unique,
		"name": item.display_name,
	}


## null, wenn Grundform oder einzigartiger Gegenstand nicht mehr existieren.
static func item_from_dict(data: Dictionary, db: ItemDatabase = null) -> ItemInstance:
	if db == null:
		db = ItemDatabase.get_default()
	if data.is_empty():
		return null
	var item := ItemInstance.new()
	item.uid = str(data.get("uid", "0")).to_int()
	item.rarity = int(data.get("rarity", 0)) as Enums.Rarity
	item.item_level = int(data.get("level", 1))
	item.unique = bool(data.get("unique", false))
	item.display_name = str(data.get("name", ""))
	var aspect_id := StringName(str(data.get("aspect", "")))
	if item.unique:
		var def := db.get_unique_by_power(aspect_id)
		if def == null:
			return null
		item.base = def.base
		item.aspect = def.power
	else:
		item.base = db.get_base(StringName(str(data.get("base", ""))))
		if item.base == null:
			return null
		item.aspect = db.get_aspect(aspect_id) if aspect_id != &"" else null
	for entry: Variant in data.get("affixes", []):
		if not entry is Array or (entry as Array).size() < 2:
			continue
		var affix := db.get_affix(StringName(str(entry[0])))
		if affix == null:
			continue
		var roll := AffixRoll.new()
		roll.affix = affix
		# Erneut runden: JSON speichert Kommazahlen nicht immer bitgenau.
		roll.value = ItemGenerator.round_affix_value(affix, float(entry[1]))
		item.affixes.append(roll)
	return item


static func inventory_to_dict(inventory: Inventory) -> Dictionary:
	var entries: Array = []
	for item in inventory.get_items():
		var cell := inventory.get_position_of(item)
		entries.append({"item": item_to_dict(item), "x": cell.x, "y": cell.y})
	return {"gold": inventory.gold, "items": entries}


## Ersetzt den Inhalt des Inventars. Gold wird ohne gold_changed-Signal gesetzt.
static func inventory_from_dict(
	inventory: Inventory, data: Dictionary, db: ItemDatabase = null
) -> void:
	inventory.clear()
	inventory.gold = int(data.get("gold", 0))
	for entry: Variant in data.get("items", []):
		if not entry is Dictionary:
			continue
		var item := item_from_dict(entry.get("item", {}), db)
		if item == null:
			continue
		var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		if not inventory.place_item(item, cell):
			inventory.add_item(item)


static func equipment_to_dict(equipment: Equipment) -> Dictionary:
	var result := {}
	var equipped := equipment.get_equipped()
	for slot: Enums.Slot in equipped:
		result[str(int(slot))] = item_to_dict(equipped[slot])
	return result


static func equipment_from_dict(
	equipment: Equipment, data: Dictionary, db: ItemDatabase = null
) -> void:
	equipment.clear()
	for key: Variant in data:
		var item := item_from_dict(data[key], db)
		if item != null:
			equipment.equip(item, int(str(key)))
