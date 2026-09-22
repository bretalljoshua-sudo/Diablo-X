class_name NameGenerator
extends RefCounted
## Namen für gewürfelte Gegenstände (Bausteine in data/items/name_parts.tres).
##
## Normal: Grundform („Kettenhemd“). Magisch: Grundform + Zusatz des stärksten Affixes
## („Kettenhemd der Wehr“). Selten: zusammengesetztes Wort („Grabeszorn“). Legendär:
## Grundform + Aspektname ohne „Aspekt “ („Kriegsaxt des Mahlstroms“). Einzigartig: fester Name.

const ASPECT_PREFIX := "Aspekt "


static func generate(item: ItemInstance, parts: NameParts, rng: RandomNumberGenerator) -> String:
	if item == null or item.base == null:
		return ""
	var base_name := item.base.display_name
	match item.rarity:
		Enums.Rarity.MAGIC:
			var suffix := _suffix_for(item, parts)
			return base_name if suffix.is_empty() else "%s %s" % [base_name, suffix]
		Enums.Rarity.RARE:
			return _rare_name(parts, rng, base_name)
		Enums.Rarity.LEGENDARY:
			if item.aspect != null:
				return "%s %s" % [base_name, item.aspect.display_name.trim_prefix(ASPECT_PREFIX)]
			return base_name
		Enums.Rarity.UNIQUE:
			return item.display_name if not item.display_name.is_empty() else base_name
	return base_name


## Zusatz des Affixes mit dem größten Anteil an seinem Höchstwert.
static func _suffix_for(item: ItemInstance, parts: NameParts) -> String:
	if parts == null:
		return ""
	var best: AffixRoll = null
	var best_share := -1.0
	for roll in item.affixes:
		if roll == null or roll.affix == null or not parts.suffixes.has(roll.affix.stat):
			continue
		var share := roll.value / maxf(absf(roll.affix.max_value), 0.0001)
		if share > best_share:
			best_share = share
			best = roll
	return parts.suffixes[best.affix.stat] if best != null else ""


static func _rare_name(parts: NameParts, rng: RandomNumberGenerator, fallback: String) -> String:
	if parts == null or parts.rare_first.is_empty() or parts.rare_second.is_empty():
		return fallback
	var first := parts.rare_first[rng.randi_range(0, parts.rare_first.size() - 1)]
	var second := parts.rare_second[rng.randi_range(0, parts.rare_second.size() - 1)]
	return first + second
