class_name ItemGenerator
extends RefCounted
## Würfelt Gegenstände: Grundform aus der Beutetabelle, Seltenheit nach Gewicht und Stufe,
## Affixe, Aspekt oder einzigartige Kraft, Name. Aller Zufall kommt aus dem übergebenen Strom.

var database: ItemDatabase


func _init(p_database: ItemDatabase = null) -> void:
	database = p_database if p_database != null else ItemDatabase.get_default()


## Würfelt die Gegenstände eines Drops (ohne Gold).
## Eine Tabelle ohne Einträge (oder null) liefert genau einen Gegenstand aus allen Grundformen.
func roll_items(table: LootTable, level: int, rng: RandomNumberGenerator) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	var count := 1
	var bonus := 0.0
	var min_rarity := Enums.Rarity.NORMAL
	if table != null and not table.entries.is_empty():
		count = rng.randi_range(table.item_count.x, maxi(table.item_count.x, table.item_count.y))
	if table != null:
		bonus = table.rarity_bonus
		min_rarity = table.min_rarity
	for i in count:
		var rarity := database.rarity.roll(level, rng, bonus, min_rarity)
		var item := create_item(pick_base(table, level, rng), rarity, level, rng)
		if item != null:
			result.append(item)
	return result


## Wählt eine Grundform nach Gewicht. Formen über der Stufe fallen weg.
func pick_base(table: LootTable, level: int, rng: RandomNumberGenerator) -> ItemBase:
	var candidates: Array[ItemBase] = []
	var weights: Array[float] = []
	if table != null and not table.entries.is_empty():
		for entry in table.entries:
			if entry != null and entry.item != null and entry.item.min_level <= level:
				candidates.append(entry.item)
				weights.append(entry.weight)
	else:
		for base in database.bases:
			if base.min_level <= level:
				candidates.append(base)
				weights.append(1.0)
	var index := WeightedPick.pick_index(weights, rng)
	if index < 0:
		# Alles zu hochstufig: die niedrigste Form der Tabelle nehmen.
		return _lowest_base(table)
	return candidates[index]


## Erzeugt einen Gegenstand. UNIQUE ignoriert base und wählt einen einzigartigen Gegenstand;
## gibt es keinen, wird daraus LEGENDARY. Gibt es keine Aspekte, wird aus LEGENDARY RARE.
func create_item(
	base: ItemBase, rarity: Enums.Rarity, level: int, rng: RandomNumberGenerator
) -> ItemInstance:
	if rarity == Enums.Rarity.UNIQUE:
		var def := _pick_unique(rng)
		if def != null:
			return create_unique(def, level, rng)
		rarity = Enums.Rarity.LEGENDARY
	if rarity == Enums.Rarity.LEGENDARY and database.aspects.is_empty():
		rarity = Enums.Rarity.RARE
	if base == null:
		return null
	var item := ItemInstance.new()
	item.uid = _new_uid(rng)
	item.base = base
	item.rarity = rarity
	item.item_level = level
	var counts := database.rarity.affix_count_range(rarity)
	var affix_count := rng.randi_range(counts.x, maxi(counts.x, counts.y))
	item.affixes = roll_affixes(base, affix_count, level, rng)
	if rarity == Enums.Rarity.LEGENDARY:
		item.aspect = database.aspects[rng.randi_range(0, database.aspects.size() - 1)]
	item.display_name = NameGenerator.generate(item, database.name_parts, rng)
	return item


func create_unique(def: UniqueDef, level: int, rng: RandomNumberGenerator) -> ItemInstance:
	var item := ItemInstance.new()
	item.uid = _new_uid(rng)
	item.base = def.base
	item.rarity = Enums.Rarity.UNIQUE
	item.item_level = level
	item.unique = true
	item.aspect = def.power
	for roll in def.affixes:
		item.affixes.append(roll.duplicate())
	item.display_name = def.display_name
	return item


## Würfelt count verschiedene Affixe (jeder Stat höchstens einmal).
func roll_affixes(
	base: ItemBase, count: int, level: int, rng: RandomNumberGenerator
) -> Array[AffixRoll]:
	var result: Array[AffixRoll] = []
	var pool := database.affixes_for(base)
	var used_stats: Array[Enums.Stat] = []
	while result.size() < count:
		var weights: Array[float] = []
		for affix in pool:
			weights.append(0.0 if affix.stat in used_stats else affix.weight)
		var index := WeightedPick.pick_index(weights, rng)
		if index < 0:
			break
		var roll := AffixRoll.new()
		roll.affix = pool[index]
		roll.value = roll_affix_value(pool[index], level, rng)
		used_stats.append(pool[index].stat)
		result.append(roll)
	return result


## Wert eines Affixes. Der Bereich min bis max gilt für alle Stufen: Stufe 1 würfelt in der
## unteren Hälfte, max_level in der oberen, dazwischen verschiebt sich das Fenster.
func roll_affix_value(affix: AffixDef, level: int, rng: RandomNumberGenerator) -> float:
	var shift := 0.5 * database.rarity.level_progress(level)
	var t := rng.randf_range(shift, shift + 0.5)
	return round_affix_value(affix, lerpf(affix.min_value, affix.max_value, t))


## Rundet ganze Werte auf ganze Zahlen und Prozentwerte auf 0,1 %.
static func round_affix_value(affix: AffixDef, value: float) -> float:
	if ItemText.is_percent(affix.stat):
		return snappedf(value, 0.001)
	if absf(affix.max_value) >= 10.0:
		return roundf(value)
	return snappedf(value, 0.1)


func _pick_unique(rng: RandomNumberGenerator) -> UniqueDef:
	var weights: Array[float] = []
	for def in database.uniques:
		weights.append(def.weight if def.base != null else 0.0)
	var index := WeightedPick.pick_index(weights, rng)
	return database.uniques[index] if index >= 0 else null


func _lowest_base(table: LootTable) -> ItemBase:
	var pool: Array[ItemBase] = []
	if table != null and not table.entries.is_empty():
		for entry in table.entries:
			if entry != null and entry.item != null:
				pool.append(entry.item)
	else:
		pool = database.bases
	var best: ItemBase = null
	for base in pool:
		if best == null or base.min_level < best.min_level:
			best = base
	return best


static func _new_uid(rng: RandomNumberGenerator) -> int:
	# 0 steht für „keine uid“, deshalb nie 0.
	return (rng.randi() << 31 | rng.randi()) & 0x3FFFFFFFFFFFFFFF | 1
