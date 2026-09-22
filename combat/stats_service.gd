extends Node
## Autoload „Stats“. ERSATZVERSION aus AP0: liefert die Werte aus entity.stats
## (falls vorhanden) oder feste Grundwerte. AP2 baut Grundwert + Ausrüstung + Effekte.
##
## Vertrag: get_stat(entity: Node, stat: Enums.Stat) -> float

const DEFAULTS: Dictionary[Enums.Stat, float] = {
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


func get_stat(entity: Node, stat: Enums.Stat) -> float:
	var fallback: float = DEFAULTS.get(stat, 0.0)
	if entity != null and "stats" in entity:
		var block: Variant = entity.get("stats")
		if block is StatBlock:
			return (block as StatBlock).get_value(stat, fallback)
	return fallback
