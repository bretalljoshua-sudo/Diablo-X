class_name EnemySpawnTable
extends Resource
## Welche Gegnergruppen auf einer Ebene erscheinen (data/enemies/spawn_tables/depth_<n>.tres).

@export var groups: Array[EnemySpawnGroup] = []
## Stufe der Gegner.
@export var level: int = 1
## Chance, dass eine Gruppe von einem Elite-Gegner angeführt wird.
@export_range(0.0, 1.0) var elite_chance: float = 0.15
## Anteil der Spawnpunkte einer Ebene, an denen eine Gruppe erscheint.
@export_range(0.0, 1.0) var fill_ratio: float = 1.0


func pick_group(rng: RandomNumberGenerator) -> EnemySpawnGroup:
	var total := 0.0
	for group in groups:
		total += maxf(group.weight, 0.0)
	if total <= 0.0:
		return null
	var roll := rng.randf() * total
	for group in groups:
		roll -= maxf(group.weight, 0.0)
		if roll <= 0.0:
			return group
	return groups[-1]
