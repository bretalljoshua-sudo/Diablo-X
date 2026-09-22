class_name StatBlock
extends Resource
## Zuordnung Enums.Stat → Wert. Mehrere Blöcke lassen sich addieren
## (Grundwerte + Ausrüstung + Effekte).

@export var values: Dictionary[Enums.Stat, float] = {}


static func from_dict(data: Dictionary) -> StatBlock:
	var block := StatBlock.new()
	for key: Variant in data:
		block.values[key as Enums.Stat] = float(data[key])
	return block


func get_value(stat: Enums.Stat, default: float = 0.0) -> float:
	return values.get(stat, default)


func set_value(stat: Enums.Stat, value: float) -> void:
	values[stat] = value


## Addiert die Werte eines anderen Blocks in diesen Block.
func add(other: StatBlock) -> void:
	if other == null:
		return
	for stat: Enums.Stat in other.values:
		values[stat] = get_value(stat) + other.values[stat]


## Liefert einen neuen Block mit der Summe aus diesem und dem anderen.
func plus(other: StatBlock) -> StatBlock:
	var result := StatBlock.new()
	result.add(self)
	result.add(other)
	return result
