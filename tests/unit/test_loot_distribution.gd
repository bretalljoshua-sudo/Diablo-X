extends GutTest
## AP4 „Fertig, wenn“: 10.000 simulierte Drops treffen die geplante Seltenheitsverteilung.
## Die geplanten Anteile stehen hier fest (siehe docs/pakete/AP4.md). Ändert jemand
## data/loot_tables/rarity.tres, muss er Plan und Test bewusst mit anpassen.

const DROPS := 10000

## Geplante Anteile je Stufe: Normal, Magisch, Selten, Legendär, Einzigartig.
const PLANNED := {
	1: [0.70, 0.25, 0.045, 0.005, 0.0],
	5: [0.5667, 0.2944, 0.105, 0.0272, 0.0067],
	10: [0.40, 0.35, 0.18, 0.055, 0.015],
}


func _table() -> LootTable:
	var table := (load("res://data/loot_tables/normal.tres") as LootTable).duplicate()
	table.item_count = Vector2i(1, 1)
	return table


func _simulate(table: LootTable, level: int, seed_value: int) -> Array[float]:
	var counts: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	var total := 0
	var rng := Rng.make(seed_value)
	for i in DROPS:
		for item in Loot.roll_drop(table, level, rng):
			counts[item.rarity] += 1.0
			total += 1
	assert_eq(total, DROPS, "genau ein Gegenstand pro Drop")
	for i in counts.size():
		counts[i] /= float(total)
	return counts


func _assert_matches_plan(level: int, seed_value: int) -> void:
	var actual := _simulate(_table(), level, seed_value)
	var planned: Array = PLANNED[level]
	for rarity in planned.size():
		var p: float = planned[rarity]
		# 4 Standardabweichungen plus kleiner Rundungspuffer.
		var tolerance := 4.0 * sqrt(p * (1.0 - p) / DROPS) + 0.002
		assert_almost_eq(
			actual[rarity],
			p,
			tolerance,
			(
				"Stufe %d, %s: %.2f %% statt %.2f %%"
				% [level, ItemText.rarity_name(rarity), actual[rarity] * 100.0, p * 100.0]
			)
		)


func test_distribution_level_1() -> void:
	_assert_matches_plan(1, 1001)


func test_distribution_level_5() -> void:
	_assert_matches_plan(5, 1005)


func test_distribution_level_10() -> void:
	_assert_matches_plan(10, 1010)


func test_rarity_data_matches_plan() -> void:
	var settings := ItemDatabase.get_default().rarity
	for level: int in PLANNED:
		var planned: Array = PLANNED[level]
		for rarity in planned.size():
			assert_almost_eq(settings.probability(rarity, level), float(planned[rarity]), 0.0005)


func test_no_uniques_at_level_1_and_more_rares_later() -> void:
	var settings := ItemDatabase.get_default().rarity
	assert_eq(settings.probability(Enums.Rarity.UNIQUE, 1), 0.0)
	assert_gt(
		settings.probability(Enums.Rarity.RARE, 10), settings.probability(Enums.Rarity.RARE, 1)
	)


func test_boss_table_drops_at_least_rare() -> void:
	var boss := load("res://data/loot_tables/boss.tres") as LootTable
	var rng := Rng.make(7)
	for i in 200:
		var drops := Loot.roll_drop(boss, 3, rng)
		assert_between(drops.size(), 3, 4)
		for item in drops:
			assert_true(item.rarity >= Enums.Rarity.RARE, "Boss-Beute mindestens selten")


func test_elite_bonus_raises_better_rarities() -> void:
	var settings := ItemDatabase.get_default().rarity
	var elite := load("res://data/loot_tables/elite.tres") as LootTable
	assert_gt(
		settings.probability(Enums.Rarity.LEGENDARY, 1, elite.rarity_bonus),
		settings.probability(Enums.Rarity.LEGENDARY, 1)
	)
	assert_lt(
		settings.probability(Enums.Rarity.NORMAL, 1, elite.rarity_bonus),
		settings.probability(Enums.Rarity.NORMAL, 1)
	)
