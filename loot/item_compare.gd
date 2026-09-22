class_name ItemCompare
extends RefCounted
## Vergleich zweier Gegenstände für Tooltips und automatisches Ausrüsten.

## Grobe Gewichtung je Stat für score(): wie viel „Schaden“ ist ein Punkt des Stats wert.
const SCORE_WEIGHTS: Dictionary[Enums.Stat, float] = {
	Enums.Stat.MAX_LIFE: 0.3,
	Enums.Stat.ARMOR: 0.4,
	Enums.Stat.DAMAGE: 1.0,
	Enums.Stat.ATTACK_SPEED: 60.0,
	Enums.Stat.CRIT_CHANCE: 100.0,
	Enums.Stat.CRIT_DAMAGE: 30.0,
	Enums.Stat.MOVE_SPEED: 8.0,
	Enums.Stat.LIFE_ON_HIT: 1.5,
	Enums.Stat.RESOURCE_MAX: 0.3,
	Enums.Stat.RESOURCE_REGEN: 3.0,
	Enums.Stat.COOLDOWN_REDUCTION: 80.0,
	Enums.Stat.FIRE_RESIST: 20.0,
	Enums.Stat.COLD_RESIST: 20.0,
	Enums.Stat.POISON_RESIST: 20.0,
}
## Zuschlag für Aspekt oder einzigartige Kraft.
const POWER_SCORE := 15.0


## Unterschied candidate minus current je Stat. null zählt als leerer Platz.
static func diff(current: ItemInstance, candidate: ItemInstance) -> StatBlock:
	var result := StatBlock.new()
	if candidate != null:
		result.add(candidate.get_stats())
	if current != null:
		var current_stats := current.get_stats()
		for stat: Enums.Stat in current_stats.values:
			result.set_value(stat, result.get_value(stat) - current_stats.values[stat])
	for stat: Enums.Stat in result.values.keys():
		if is_zero_approx(result.values[stat]):
			result.values.erase(stat)
	return result


## Zeilen für den Vergleichs-Tooltip, sortiert nach Stat:
## [{stat, delta, text, better}], better = true heißt grün.
static func lines(current: ItemInstance, candidate: ItemInstance) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var delta := diff(current, candidate)
	var stats: Array = delta.values.keys()
	stats.sort()
	for stat: Enums.Stat in stats:
		var value: float = delta.values[stat]
		(
			result
			. append(
				{
					"stat": stat,
					"delta": value,
					"text":
					"%s %s" % [ItemText.format_delta(stat, value), ItemText.stat_name(stat)],
					"better": value > 0.0,
				}
			)
		)
	return result


## Wertungszahl eines Gegenstands (grob, für „besser/schlechter“ und Auto-Ausrüsten).
static func score(item: ItemInstance) -> float:
	if item == null:
		return 0.0
	var total := 0.0
	var stats := item.get_stats()
	for stat: Enums.Stat in stats.values:
		total += stats.values[stat] * SCORE_WEIGHTS.get(stat, 1.0)
	if item.aspect != null:
		total += POWER_SCORE
	return total


static func is_upgrade(current: ItemInstance, candidate: ItemInstance) -> bool:
	return score(candidate) > score(current)
