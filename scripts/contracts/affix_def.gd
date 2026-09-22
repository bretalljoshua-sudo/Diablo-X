class_name AffixDef
extends Resource
## Ein möglicher Zusatzwert auf Gegenständen, zum Beispiel „+x % kritische Trefferchance“.

@export var id: StringName = &""
## Anzeigetext mit Platzhalter {value}, zum Beispiel "+{value} Rüstung".
@export var text: String = ""
@export var stat: Enums.Stat = Enums.Stat.DAMAGE
@export var min_value: float = 0.0
@export var max_value: float = 0.0
## Plätze, auf denen das Affix erscheinen darf. Leer = überall.
@export var allowed_slots: Array[Enums.Slot] = []
## Relative Häufigkeit beim Würfeln.
@export var weight: float = 1.0
