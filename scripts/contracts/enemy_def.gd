class_name EnemyDef
extends Resource
## Gegnertyp als Daten. Szene und KI baut AP3.

@export var id: StringName = &""
@export var display_name: String = ""
@export var scene: PackedScene
## Werte auf Stufe 1.
@export var base_stats: StatBlock
## Zuwachs je Stufe über 1, wird pro Stufe addiert.
@export var stats_per_level: StatBlock
## Name des Verhaltens, das AP3 auswertet, zum Beispiel &"swarm" oder &"ranged".
@export var behavior: StringName = &""
@export var loot_table: LootTable
@export var experience: int = 10
