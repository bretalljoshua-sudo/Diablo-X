class_name Enums
## Gemeinsame Aufzählungen für alle Pakete.
## Neue Werte nur am Ende anhängen: .tres-Dateien speichern die Zahl, nicht den Namen.

enum Stat {
	MAX_LIFE,
	ARMOR,
	DAMAGE,
	ATTACK_SPEED,
	CRIT_CHANCE,
	CRIT_DAMAGE,
	MOVE_SPEED,
	LIFE_ON_HIT,
	RESOURCE_MAX,
	RESOURCE_REGEN,
	COOLDOWN_REDUCTION,
	FIRE_RESIST,
	COLD_RESIST,
	POISON_RESIST,
}

enum DamageType { PHYSICAL, FIRE, COLD, POISON }

enum Rarity { NORMAL, MAGIC, RARE, LEGENDARY, UNIQUE }

enum Slot { HELM, CHEST, GLOVES, PANTS, BOOTS, WEAPON, AMULET, RING_1, RING_2 }

enum Faction { PLAYER, ENEMY, NEUTRAL }

enum SkillCategory { BASIC, CORE, DEFENSIVE, MOBILITY, ULTIMATE }

enum Targeting { MELEE_ARC, SELF_AOE, GROUND_TARGET, PROJECTILE, DASH, CHANNEL }
