extends Node
## Autoload „Loot“. ERSATZVERSION aus AP0: liefert genau einen normalen Gegenstand,
## den ersten Eintrag der Tabelle oder ein festes Übungsschwert. AP4 ersetzt den Inhalt.
##
## Vertrag: roll_drop(table: LootTable, level: int, rng: RandomNumberGenerator)
##          -> Array[ItemInstance]
## Den Zufallsstrom liefert Rng.stream(&"loot", …), damit Drops reproduzierbar sind.

var _placeholder_base: ItemBase


func roll_drop(table: LootTable, level: int, rng: RandomNumberGenerator) -> Array[ItemInstance]:
	var base: ItemBase = null
	if table != null and not table.entries.is_empty():
		base = table.entries[0].item
	if base == null:
		base = get_placeholder_base()
	var item := ItemInstance.new()
	item.uid = rng.randi() if rng != null else randi()
	item.base = base
	item.rarity = Enums.Rarity.NORMAL
	item.item_level = level
	var drops: Array[ItemInstance] = [item]
	return drops


func get_placeholder_base() -> ItemBase:
	if _placeholder_base == null:
		_placeholder_base = ItemBase.new()
		_placeholder_base.id = &"placeholder_sword"
		_placeholder_base.display_name = "Übungsschwert"
		_placeholder_base.slot = Enums.Slot.WEAPON
		_placeholder_base.base_stats = StatBlock.from_dict({Enums.Stat.DAMAGE: 5.0})
	return _placeholder_base
