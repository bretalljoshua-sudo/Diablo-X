class_name ItemValue
extends RefCounted
## Verkaufs- und Kaufpreise. Händler (AP7) zahlt sell_value() und verlangt buy_price().

const RARITY_FACTOR: Dictionary[Enums.Rarity, float] = {
	Enums.Rarity.NORMAL: 1.0,
	Enums.Rarity.MAGIC: 2.5,
	Enums.Rarity.RARE: 5.0,
	Enums.Rarity.LEGENDARY: 12.0,
	Enums.Rarity.UNIQUE: 15.0,
}
const BASE_VALUE := 5
const VALUE_PER_LEVEL := 3
const VALUE_PER_AFFIX := 4
const BUY_FACTOR := 5


static func sell_value(item: ItemInstance) -> int:
	if item == null:
		return 0
	var raw := BASE_VALUE + VALUE_PER_LEVEL * maxi(item.item_level, 1)
	raw += VALUE_PER_AFFIX * item.affixes.size()
	return int(roundf(raw * RARITY_FACTOR.get(item.rarity, 1.0)))


static func buy_price(item: ItemInstance) -> int:
	return sell_value(item) * BUY_FACTOR
