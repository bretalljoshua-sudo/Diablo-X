class_name RaritySettings
extends Resource
## Geplante Seltenheitsverteilung und Affix-Anzahl je Seltenheit
## (Daten: data/loot_tables/rarity.tres).
##
## Die Gewichte gelten für Gegnerstufe 1 und für max_level; dazwischen wird linear gemischt,
## darüber gilt der Wert von max_level. Die Gewichte müssen keine Summe von 100 ergeben.

## Gewicht je Seltenheit auf Stufe 1.
@export var weights_at_level_1: Dictionary[Enums.Rarity, float] = {}
## Gewicht je Seltenheit ab max_level.
@export var weights_at_max_level: Dictionary[Enums.Rarity, float] = {}
@export var max_level: int = 10
## Anzahl zufälliger Affixe je Seltenheit (min, max). Einzigartige haben feste Werte.
@export var affix_counts: Dictionary[Enums.Rarity, Vector2i] = {}


## Gewichte für eine Stufe. bonus erhöht Magisch bis Einzigartig (0.5 = +50 %),
## Seltenheiten unter min_rarity fallen weg.
func weights_for(
	level: int, bonus: float = 0.0, min_rarity: Enums.Rarity = Enums.Rarity.NORMAL
) -> Dictionary[Enums.Rarity, float]:
	var t := level_progress(level)
	var result: Dictionary[Enums.Rarity, float] = {}
	for rarity: Enums.Rarity in Enums.Rarity.values():
		var weight := lerpf(
			weights_at_level_1.get(rarity, 0.0), weights_at_max_level.get(rarity, 0.0), t
		)
		if rarity != Enums.Rarity.NORMAL:
			weight *= 1.0 + maxf(bonus, 0.0)
		if rarity < min_rarity:
			weight = 0.0
		result[rarity] = maxf(weight, 0.0)
	return result


## Wahrscheinlichkeit (0 bis 1) einer Seltenheit.
func probability(
	rarity: Enums.Rarity,
	level: int,
	bonus: float = 0.0,
	min_rarity: Enums.Rarity = Enums.Rarity.NORMAL
) -> float:
	var weights := weights_for(level, bonus, min_rarity)
	var total := 0.0
	for weight: float in weights.values():
		total += weight
	return weights[rarity] / total if total > 0.0 else 0.0


func roll(
	level: int,
	rng: RandomNumberGenerator,
	bonus: float = 0.0,
	min_rarity: Enums.Rarity = Enums.Rarity.NORMAL
) -> Enums.Rarity:
	var weights := weights_for(level, bonus, min_rarity)
	var keys: Array = weights.keys()
	var index := WeightedPick.pick_index(weights.values(), rng)
	return keys[index] if index >= 0 else min_rarity


func affix_count_range(rarity: Enums.Rarity) -> Vector2i:
	return affix_counts.get(rarity, Vector2i.ZERO)


## 0 auf Stufe 1, 1 ab max_level.
func level_progress(level: int) -> float:
	if max_level <= 1:
		return 1.0
	return clampf(float(level - 1) / float(max_level - 1), 0.0, 1.0)
