class_name LootTable
extends Resource
## Was ein Gegner oder eine Truhe fallen lassen kann.

@export var entries: Array[LootEntry] = []
## Anzahl gewürfelter Gegenstände pro Drop (min, max).
@export var item_count: Vector2i = Vector2i(0, 1)
## Goldmenge pro Drop (min, max).
@export var gold: Vector2i = Vector2i(0, 0)
## Mindestseltenheit aller Gegenstände dieser Tabelle, zum Beispiel RARE für den Boss.
@export var min_rarity: Enums.Rarity = Enums.Rarity.NORMAL
## Zuschlag auf die Gewichte von Magisch bis Einzigartig: 0.5 = 50 % häufiger (zum Beispiel Elite).
@export var rarity_bonus: float = 0.0
