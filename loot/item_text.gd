class_name ItemText
extends RefCounted
## Texte und Farben für Gegenstände: Stat-Namen, Affix-Zeilen, Seltenheit, Tooltip-Zeilen.
## Anteile (Krit-Chance, Resistenzen, …) stehen intern als 0.05 und werden als „5 %“ gezeigt.

const PERCENT_STATS: Array[Enums.Stat] = [
	Enums.Stat.ATTACK_SPEED,
	Enums.Stat.CRIT_CHANCE,
	Enums.Stat.CRIT_DAMAGE,
	Enums.Stat.COOLDOWN_REDUCTION,
	Enums.Stat.FIRE_RESIST,
	Enums.Stat.COLD_RESIST,
	Enums.Stat.POISON_RESIST,
]

const STAT_NAMES: Dictionary[Enums.Stat, String] = {
	Enums.Stat.MAX_LIFE: "Leben",
	Enums.Stat.ARMOR: "Rüstung",
	Enums.Stat.DAMAGE: "Schaden",
	Enums.Stat.ATTACK_SPEED: "Angriffsgeschwindigkeit",
	Enums.Stat.CRIT_CHANCE: "kritische Trefferchance",
	Enums.Stat.CRIT_DAMAGE: "kritischer Schaden",
	Enums.Stat.MOVE_SPEED: "Laufgeschwindigkeit",
	Enums.Stat.LIFE_ON_HIT: "Leben pro Treffer",
	Enums.Stat.RESOURCE_MAX: "maximale Wut",
	Enums.Stat.RESOURCE_REGEN: "Wut pro Sekunde",
	Enums.Stat.COOLDOWN_REDUCTION: "Abklingzeitverringerung",
	Enums.Stat.FIRE_RESIST: "Feuerresistenz",
	Enums.Stat.COLD_RESIST: "Kälteresistenz",
	Enums.Stat.POISON_RESIST: "Giftresistenz",
}

const RARITY_NAMES: Dictionary[Enums.Rarity, String] = {
	Enums.Rarity.NORMAL: "Normal",
	Enums.Rarity.MAGIC: "Magisch",
	Enums.Rarity.RARE: "Selten",
	Enums.Rarity.LEGENDARY: "Legendär",
	Enums.Rarity.UNIQUE: "Einzigartig",
}

const RARITY_COLORS: Dictionary[Enums.Rarity, Color] = {
	Enums.Rarity.NORMAL: Color(0.85, 0.85, 0.85),
	Enums.Rarity.MAGIC: Color(0.4, 0.55, 1.0),
	Enums.Rarity.RARE: Color(1.0, 0.9, 0.3),
	Enums.Rarity.LEGENDARY: Color(1.0, 0.5, 0.1),
	Enums.Rarity.UNIQUE: Color(0.85, 0.7, 0.45),
}

const SLOT_NAMES: Dictionary[Enums.Slot, String] = {
	Enums.Slot.HELM: "Helm",
	Enums.Slot.CHEST: "Brust",
	Enums.Slot.GLOVES: "Handschuhe",
	Enums.Slot.PANTS: "Hose",
	Enums.Slot.BOOTS: "Stiefel",
	Enums.Slot.WEAPON: "Waffe",
	Enums.Slot.AMULET: "Amulett",
	Enums.Slot.RING_1: "Ring",
	Enums.Slot.RING_2: "Ring",
}


static func is_percent(stat: Enums.Stat) -> bool:
	return stat in PERCENT_STATS


static func stat_name(stat: Enums.Stat) -> String:
	return STAT_NAMES.get(stat, "?")


static func rarity_name(rarity: Enums.Rarity) -> String:
	return RARITY_NAMES.get(rarity, "?")


static func rarity_color(rarity: Enums.Rarity) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


static func slot_name(slot: Enums.Slot) -> String:
	return SLOT_NAMES.get(slot, "?")


## Zahl ohne Vorzeichen: "12 %" oder "8" oder "0,5".
static func format_value(stat: Enums.Stat, value: float) -> String:
	if is_percent(stat):
		return "%s %%" % _number(value * 100.0)
	return _number(value)


## Mit Vorzeichen, für Vergleiche: "+12 %" oder "−3".
static func format_delta(stat: Enums.Stat, delta: float) -> String:
	var prefix := "+" if delta >= 0.0 else "−"
	return prefix + format_value(stat, absf(delta))


## "+12 % kritische Trefferchance" oder der Text aus AffixDef mit {value}.
static func affix_line(roll: AffixRoll) -> String:
	if roll == null or roll.affix == null:
		return ""
	var value := format_value(roll.affix.stat, roll.value)
	if not roll.affix.text.is_empty():
		return roll.affix.text.replace("{value}", value)
	return "+%s %s" % [value, stat_name(roll.affix.stat)]


## Beschreibung eines Aspekts mit eingesetzten Werten aus params.
static func aspect_text(aspect: AspectDef) -> String:
	if aspect == null:
		return ""
	var text := aspect.description
	for key: StringName in aspect.params:
		text = text.replace("{%s}" % key, _number(aspect.params[key]))
	return text


## Alle Zeilen für einen Tooltip (ohne Vergleich), erste Zeile ist der Name.
static func tooltip_lines(item: ItemInstance) -> PackedStringArray:
	var lines := PackedStringArray()
	if item == null or item.base == null:
		return lines
	lines.append(item.get_display_name())
	lines.append(
		"%s %s · Stufe %d" % [rarity_name(item.rarity), item.base.display_name, item.item_level]
	)
	if item.base.base_stats != null:
		for stat: Enums.Stat in item.base.base_stats.values:
			var value := item.base.base_stats.values[stat]
			lines.append("%s %s" % [format_value(stat, value), stat_name(stat)])
	for roll in item.affixes:
		lines.append(affix_line(roll))
	if item.aspect != null:
		lines.append(aspect_text(item.aspect))
	lines.append("Verkaufswert: %d Gold" % ItemValue.sell_value(item))
	return lines


## Zahl mit höchstens einer Nachkommastelle und deutschem Komma.
static func _number(value: float) -> String:
	var rounded := snappedf(value, 0.1)
	if is_equal_approx(rounded, roundf(rounded)):
		return str(int(roundf(rounded)))
	return ("%.1f" % rounded).replace(".", ",")
