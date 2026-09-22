extends Node
## Autoload „Stats“: Werte einer Figur aus Grundwert + Ausrüstung + Effekte.
##
## Vertrag: get_stat(entity: Node, stat: Enums.Stat) -> float
##
## Quelle der Werte, in dieser Reihenfolge:
##   1. StatsComponent an der Figur (Figur selbst oder direktes Kind)
##   2. Eigenschaft `stats: StatBlock` an der Figur (Ersatz-Konvention aus AP0)
##   3. StatDefaults
## Ausrüstung: EventBus.player_equipped(slot, item) setzt am Spieler (Game.player) die feste
## Quelle &"equipment:<slot>" auf item.get_stats(); item = null nimmt sie weg. AP4 muss dafür
## nur das Signal senden.

## Standardwerte, wie in AP0 (siehe StatDefaults).
const DEFAULTS := StatDefaults.VALUES


func _ready() -> void:
	EventBus.player_equipped.connect(_on_player_equipped)


func get_stat(entity: Node, stat: Enums.Stat) -> float:
	var component := Components.stats(entity)
	if component != null:
		return component.get_value(stat)
	var fallback := StatDefaults.get_default(stat)
	if entity != null and is_instance_valid(entity) and "stats" in entity:
		var block: Variant = entity.get("stats")
		if block is StatBlock:
			return (block as StatBlock).get_value(stat, fallback)
	return fallback


func get_component(entity: Node) -> StatsComponent:
	return Components.stats(entity)


## Setzt eine feste Quelle an der Figur (zum Beispiel &"level"). Liefert false ohne StatsComponent.
func set_flat_source(entity: Node, key: StringName, block: StatBlock) -> bool:
	var component := Components.stats(entity)
	if component == null:
		return false
	component.set_flat_source(key, block)
	return true


## Setzt eine Prozent-Quelle (zum Beispiel &"shout" mit ARMOR = 0.4 für +40 % Rüstung).
func set_percent_source(entity: Node, key: StringName, block: StatBlock) -> bool:
	var component := Components.stats(entity)
	if component == null:
		return false
	component.set_percent_source(key, block)
	return true


func remove_source(entity: Node, key: StringName) -> void:
	var component := Components.stats(entity)
	if component != null:
		component.remove_source(key)


static func equipment_key(slot: Enums.Slot) -> StringName:
	return StringName("equipment:%s" % String(Enums.Slot.keys()[slot]).to_lower())


func _on_player_equipped(slot: Enums.Slot, item: ItemInstance) -> void:
	if not is_instance_valid(Game.player):
		return
	set_flat_source(Game.player, equipment_key(slot), item.get_stats() if item != null else null)
