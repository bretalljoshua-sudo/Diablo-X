class_name DifficultyCurve
extends Resource
## Schwierigkeitskurve (data/encounters/difficulty.tres): welche Stufe die Gegner einer Ebene haben
## und wie dicht sie stehen. Die Stufe folgt der Stufe des Spielers, mit festem Abstand je Ebene und
## einer Untergrenze, damit schon der erste Durchlauf nach unten schwerer wird.
##
##   Gegnerstufe = clamp(Spielerstufe + level_offset[Ebene], min_level[Ebene], max_level)

const DEFAULT_PATH := "res://data/encounters/difficulty.tres"

static var _default: DifficultyCurve

## Abstand der Gegnerstufe zur Spielerstufe je Ebene (1, 2, 3 = Boss).
@export var level_offset: Dictionary[int, int] = {1: -1, 2: 0, 3: 0}
## Mindeststufe der Gegner je Ebene.
@export var min_level: Dictionary[int, int] = {1: 1, 2: 2, 3: 3}
@export var max_level: int = 10
## Anteil der Spawnpunkte mit Gruppe je Ebene (ersetzt fill_ratio der Spawn-Tabelle von AP3).
@export var fill_ratio: Dictionary[int, float] = {}
## Elite-Chance je Ebene (ersetzt elite_chance der Spawn-Tabelle).
@export var elite_chance: Dictionary[int, float] = {}
## Anteil des Golds, den der Tod kostet.
@export_range(0.0, 1.0) var death_gold_loss: float = 0.1


static func get_default() -> DifficultyCurve:
	if _default == null:
		if ResourceLoader.exists(DEFAULT_PATH):
			_default = load(DEFAULT_PATH) as DifficultyCurve
		if _default == null:
			_default = DifficultyCurve.new()
	return _default


func enemy_level(depth: int, player_level: int) -> int:
	var level := player_level + int(level_offset.get(depth, 0))
	return clampi(maxi(level, int(min_level.get(depth, 1))), 1, max_level)


## Kopie der Spawn-Tabelle einer Ebene mit Stufe, Dichte und Elite-Chance aus dieser Kurve.
func spawn_table_for(depth: int, player_level: int) -> EnemySpawnTable:
	var source := EnemyDirector.load_spawn_table(depth)
	if source == null:
		return null
	var table := source.duplicate() as EnemySpawnTable
	table.level = enemy_level(depth, player_level)
	if fill_ratio.has(depth):
		table.fill_ratio = fill_ratio[depth]
	if elite_chance.has(depth):
		table.elite_chance = elite_chance[depth]
	return table
