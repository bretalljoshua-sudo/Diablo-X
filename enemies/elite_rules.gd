class_name EliteRules
extends Resource
## Regeln für Elite-Gegner (data/enemies/elite_rules.tres).

const DEFAULT_PATH := "res://data/enemies/elite_rules.tres"

static var _default: EliteRules

## Alle Eigenschaften, aus denen gewürfelt wird.
@export var affixes: Array[EliteAffix] = []
@export var life_multiplier: float = 2.5
@export var damage_multiplier: float = 1.3
@export var experience_multiplier: float = 3.0
## Größer als normale Gegner, damit man Elite-Gegner sofort erkennt.
@export var scale: float = 1.2
## Anzahl Eigenschaften je Stufe: Index 0 = Stufe 1. Danach gilt der letzte Wert.
@export var affix_count_by_level: Array[int] = [1, 1, 1, 2, 2, 2, 2, 3]
@export var loot_table: LootTable


func affix_count(level: int) -> int:
	if affix_count_by_level.is_empty():
		return 1
	return affix_count_by_level[clampi(level - 1, 0, affix_count_by_level.size() - 1)]


## Würfelt count verschiedene Eigenschaften.
func roll_affixes(count: int, rng: RandomNumberGenerator) -> Array[EliteAffix]:
	var pool := affixes.duplicate()
	var result: Array[EliteAffix] = []
	while result.size() < count and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		result.append(pool[index])
		pool.remove_at(index)
	return result


## Regeln aus DEFAULT_PATH (einmal geladen), sonst Standardwerte ohne Eigenschaften.
static func get_default() -> EliteRules:
	if _default == null:
		if ResourceLoader.exists(DEFAULT_PATH):
			_default = load(DEFAULT_PATH) as EliteRules
		if _default == null:
			_default = EliteRules.new()
	return _default
