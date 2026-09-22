class_name LootTable
extends Resource
## Was ein Gegner oder eine Truhe fallen lassen kann.

@export var entries: Array[LootEntry] = []
## Anzahl gewürfelter Gegenstände pro Drop (min, max).
@export var item_count: Vector2i = Vector2i(0, 1)
## Goldmenge pro Drop (min, max).
@export var gold: Vector2i = Vector2i(0, 0)
