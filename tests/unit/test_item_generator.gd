extends GutTest
## Gegenstände würfeln: Affixe, Stufen, Aspekte, einzigartige Gegenstände, Namen (AP4).

var gen: ItemGenerator
var db: ItemDatabase


func before_all() -> void:
	db = ItemDatabase.get_default()
	gen = ItemGenerator.new(db)


func _base(id: StringName) -> ItemBase:
	return db.get_base(id)


func test_affix_count_follows_rarity() -> void:
	var rng := Rng.make(3)
	var base := _base(&"chainmail")
	for rarity: Enums.Rarity in [Enums.Rarity.NORMAL, Enums.Rarity.MAGIC, Enums.Rarity.RARE]:
		var counts := db.rarity.affix_count_range(rarity)
		for i in 50:
			var item := gen.create_item(base, rarity, 5, rng)
			assert_between(item.affixes.size(), counts.x, counts.y)


func test_affixes_fit_slot_and_do_not_repeat_stats() -> void:
	var rng := Rng.make(4)
	for base in db.bases:
		var item := gen.create_item(base, Enums.Rarity.RARE, 10, rng)
		var allowed := db.affixes_for(base)
		var stats: Array[Enums.Stat] = []
		for roll in item.affixes:
			assert_true(roll.affix in allowed, "%s auf %s" % [roll.affix.id, base.id])
			assert_false(roll.affix.stat in stats, "Stat doppelt auf %s" % base.id)
			stats.append(roll.affix.stat)


func test_affix_values_scale_with_level() -> void:
	var affix := db.get_affix(&"damage_weapon")
	var rng := Rng.make(5)
	var mid := lerpf(affix.min_value, affix.max_value, 0.5)
	for i in 200:
		var low := gen.roll_affix_value(affix, 1, rng)
		var high := gen.roll_affix_value(affix, 10, rng)
		assert_between(low, affix.min_value, mid + 0.5)
		assert_between(high, mid - 0.5, affix.max_value)


func test_legendary_has_aspect_and_name() -> void:
	var item := gen.create_item(_base(&"war_axe"), Enums.Rarity.LEGENDARY, 5, Rng.make(6))
	assert_not_null(item.aspect)
	assert_true(item.aspect in db.aspects)
	assert_true(item.get_display_name().begins_with("Kriegsaxt "), item.get_display_name())
	assert_false(item.get_display_name().contains("Aspekt"))


func test_unique_has_fixed_values() -> void:
	var def := db.get_unique(&"crown_of_ashes")
	var a := gen.create_unique(def, 3, Rng.make(1))
	var b := gen.create_unique(def, 9, Rng.make(2))
	assert_eq(a.rarity, Enums.Rarity.UNIQUE)
	assert_true(a.unique)
	assert_eq(a.get_display_name(), "Krone der Asche")
	assert_eq(a.aspect, def.power)
	assert_eq(a.get_stats().values, b.get_stats().values, "feste Werte, unabhängig vom Wurf")
	a.affixes[0].value = 999.0
	assert_ne(def.affixes[0].value, 999.0, "Daten werden nicht verändert")


func test_unique_rarity_picks_unique_item() -> void:
	var item := gen.create_item(_base(&"rusty_sword"), Enums.Rarity.UNIQUE, 5, Rng.make(8))
	assert_true(item.unique)
	assert_not_null(db.get_unique_by_power(item.aspect.id))


func test_magic_and_rare_names() -> void:
	var rng := Rng.make(9)
	var magic := gen.create_item(_base(&"chainmail"), Enums.Rarity.MAGIC, 5, rng)
	assert_true(magic.get_display_name().begins_with("Kettenhemd "), magic.get_display_name())
	var rare := gen.create_item(_base(&"chainmail"), Enums.Rarity.RARE, 5, rng)
	assert_false(rare.get_display_name().is_empty())
	assert_false(rare.get_display_name().contains(" "), "seltene Namen sind ein Wort")
	var normal := gen.create_item(_base(&"chainmail"), Enums.Rarity.NORMAL, 5, rng)
	assert_eq(normal.get_display_name(), "Kettenhemd")


func test_high_level_bases_only_from_their_level() -> void:
	var table := Loot.get_table(&"normal")
	var rng := Rng.make(10)
	for i in 300:
		assert_eq(gen.pick_base(table, 1, rng).min_level, 1)
	var seen_high := false
	for i in 300:
		if gen.pick_base(table, 10, rng).min_level > 1:
			seen_high = true
	assert_true(seen_high, "auf Stufe 10 fallen auch bessere Grundformen")


func test_drops_are_reproducible() -> void:
	var table := Loot.get_table(&"elite")
	var a := Loot.roll_drop(table, 6, Rng.make(42))
	var b := Loot.roll_drop(table, 6, Rng.make(42))
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i].uid, b[i].uid)
		assert_eq(a[i].get_display_name(), b[i].get_display_name())
		assert_eq(a[i].get_stats().values, b[i].get_stats().values)


func test_uids_are_nonzero_and_distinct() -> void:
	var rng := Rng.make(11)
	var uids: Array[int] = []
	for i in 500:
		var item := gen.create_item(_base(&"copper_ring"), Enums.Rarity.MAGIC, 1, rng)
		assert_ne(item.uid, 0)
		assert_false(item.uid in uids)
		uids.append(item.uid)


func test_gold_scales_with_level() -> void:
	var table := Loot.get_table(&"normal")
	var low := 0
	var high := 0
	var rng := Rng.make(12)
	for i in 500:
		low += Loot.roll_gold(table, 1, rng)
		high += Loot.roll_gold(table, 10, rng)
	assert_between(low / 500.0, float(table.gold.x), float(table.gold.y))
	assert_gt(high, low * 2)
	assert_eq(Loot.roll_gold(LootTable.new(), 5, rng), 0, "Tabelle ohne Gold")
