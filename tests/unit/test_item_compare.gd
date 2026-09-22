extends GutTest
## Vergleich, Verkaufswert und Texte (AP4).

var db: ItemDatabase


func before_all() -> void:
	db = ItemDatabase.get_default()


func _item(base_id: StringName, affix_id: StringName = &"", value: float = 0.0) -> ItemInstance:
	var item := ItemInstance.new()
	item.base = db.get_base(base_id)
	item.item_level = 3
	if affix_id != &"":
		var roll := AffixRoll.new()
		roll.affix = db.get_affix(affix_id)
		roll.value = value
		item.affixes.append(roll)
	return item


func test_diff_is_candidate_minus_current() -> void:
	var current := _item(&"rusty_sword", &"crit_chance_weapon", 0.05)
	var candidate := _item(&"war_axe")
	var delta := ItemCompare.diff(current, candidate)
	assert_eq(delta.get_value(Enums.Stat.DAMAGE), 6.0)
	assert_almost_eq(delta.get_value(Enums.Stat.CRIT_CHANCE), -0.05, 0.0001)
	assert_eq(ItemCompare.diff(null, candidate).get_value(Enums.Stat.DAMAGE), 14.0)
	assert_true(ItemCompare.diff(candidate, candidate).values.is_empty())


func test_lines_are_colored_and_readable() -> void:
	var current := _item(&"rusty_sword", &"crit_chance_weapon", 0.05)
	var lines := ItemCompare.lines(current, _item(&"war_axe"))
	assert_eq(lines.size(), 2)
	assert_eq(lines[0]["text"], "+6 Schaden")
	assert_true(lines[0]["better"])
	assert_eq(lines[1]["text"], "−5 % kritische Trefferchance")
	assert_false(lines[1]["better"])


func test_upgrade_and_score() -> void:
	assert_true(ItemCompare.is_upgrade(_item(&"rusty_sword"), _item(&"war_axe")))
	assert_false(ItemCompare.is_upgrade(_item(&"war_axe"), _item(&"rusty_sword")))
	assert_true(ItemCompare.is_upgrade(null, _item(&"rusty_sword")))


func test_sell_value_grows_with_rarity_and_level() -> void:
	var normal := _item(&"chainmail")
	var rare := _item(&"chainmail", &"life_chest", 50.0)
	rare.rarity = Enums.Rarity.RARE
	assert_gt(ItemValue.sell_value(normal), 0)
	assert_gt(ItemValue.sell_value(rare), ItemValue.sell_value(normal))
	var high := _item(&"chainmail")
	high.item_level = 10
	assert_gt(ItemValue.sell_value(high), ItemValue.sell_value(normal))
	assert_eq(ItemValue.buy_price(normal), ItemValue.sell_value(normal) * ItemValue.BUY_FACTOR)
	assert_eq(ItemValue.sell_value(null), 0)


func test_text_formatting() -> void:
	var roll := AffixRoll.new()
	roll.affix = db.get_affix(&"attack_speed_weapon")
	roll.value = 0.075
	assert_eq(ItemText.affix_line(roll), "+7,5 % Angriffsgeschwindigkeit")
	assert_eq(ItemText.format_delta(Enums.Stat.ARMOR, -3.0), "−3")
	var aspect := db.get_aspect(&"aspect_tremor")
	assert_eq(ItemText.aspect_text(aspect), "Sprung betäubt getroffene Gegner für 1,5 s.")


func test_tooltip_lines() -> void:
	var item := _item(&"war_axe", &"damage_weapon", 12.0)
	item.rarity = Enums.Rarity.MAGIC
	item.display_name = "Kriegsaxt der Wut"
	var lines := ItemText.tooltip_lines(item)
	assert_eq(lines[0], "Kriegsaxt der Wut")
	assert_true(lines[1].begins_with("Magisch Kriegsaxt"))
	assert_true("+12 Schaden" in lines)
	assert_true(lines[lines.size() - 1].begins_with("Verkaufswert"))
