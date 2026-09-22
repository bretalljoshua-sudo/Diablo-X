class_name StatDefaults
## Standardwerte für Stats, die eine Figur nicht selbst festlegt.
## Anteile als Zahl: 0.05 = 5 %, CRIT_DAMAGE 0.5 = +50 % Schaden bei kritischem Treffer.

const VALUES: Dictionary[Enums.Stat, float] = {
	Enums.Stat.MAX_LIFE: 100.0,
	Enums.Stat.ARMOR: 0.0,
	Enums.Stat.DAMAGE: 10.0,
	Enums.Stat.ATTACK_SPEED: 1.0,
	Enums.Stat.CRIT_CHANCE: 0.05,
	Enums.Stat.CRIT_DAMAGE: 0.5,
	Enums.Stat.MOVE_SPEED: 5.0,
	Enums.Stat.LIFE_ON_HIT: 0.0,
	Enums.Stat.RESOURCE_MAX: 100.0,
	Enums.Stat.RESOURCE_REGEN: 0.0,
	Enums.Stat.COOLDOWN_REDUCTION: 0.0,
	Enums.Stat.FIRE_RESIST: 0.0,
	Enums.Stat.COLD_RESIST: 0.0,
	Enums.Stat.POISON_RESIST: 0.0,
}


static func get_default(stat: Enums.Stat) -> float:
	return VALUES.get(stat, 0.0)
