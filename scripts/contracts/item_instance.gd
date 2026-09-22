class_name ItemInstance
extends Resource
## Ein konkreter, gewürfelter Gegenstand.

@export var uid: int = 0
@export var base: ItemBase
@export var rarity: Enums.Rarity = Enums.Rarity.NORMAL
@export var item_level: int = 1
@export var affixes: Array[AffixRoll] = []
## Legendärer Aspekt, sonst null.
@export var aspect: AspectDef
## true bei einzigartigen Gegenständen mit festen Werten.
@export var unique: bool = false
## Angezeigter Name (vom Namensgenerator in AP4), leer = base.display_name.
@export var display_name: String = ""


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	return base.display_name if base != null else "?"


## Summe aus Grundwerten und Affixen.
func get_stats() -> StatBlock:
	var result := StatBlock.new()
	if base != null:
		result.add(base.base_stats)
	for roll: AffixRoll in affixes:
		if roll != null and roll.affix != null:
			result.set_value(roll.affix.stat, result.get_value(roll.affix.stat) + roll.value)
	return result
