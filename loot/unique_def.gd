class_name UniqueDef
extends Resource
## Einzigartiger Gegenstand mit festem Namen, festen Werten und einer eigenen Kraft.
## Daten: data/items/uniques/*.tres

@export var id: StringName = &""
@export var display_name: String = ""
@export var base: ItemBase
## Feste Affixe mit festen Werten.
@export var affixes: Array[AffixRoll] = []
## Einzigartige Kraft, wirkt wie ein Aspekt über Skill-Tags (AP5).
@export var power: AspectDef
@export_multiline var flavor_text: String = ""
## Relative Häufigkeit unter den einzigartigen Gegenständen.
@export var weight: float = 1.0
