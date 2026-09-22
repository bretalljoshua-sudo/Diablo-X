class_name LevelConfig
extends Resource
## Eingabe für World.generate().

## 0 = Dorf, 1 und 2 = Dungeon-Ebenen, 3 = Bossraum.
@export var depth: int = 1
@export var room_count: int = 8
@export var is_boss_level: bool = false
## Stilrichtung für Baukasten und Licht, zum Beispiel &"catacombs".
@export var theme: StringName = &"catacombs"
