class_name EnemyDirector
extends Node
## Setzt Gegner in die Welt: einzeln, als Gruppe oder für eine ganze Ebene aus AP6.
## Besitzt den Objekt-Pool. AP9 hängt einen EnemyDirector in die Spielszene; mit
## auto_populate füllt er jede neu geladene Ebene (EventBus.level_loaded) und räumt sie
## vor dem Wechsel wieder ab (EventBus.level_unloading).

const SPAWN_TABLE_PATH := "res://data/enemies/spawn_tables/depth_%d.tres"
const NAVIGATION_WAIT_FRAMES := 30
## Liegt der nächste Punkt des Netzes weiter weg, gilt ein Punkt als nicht auf dem Netz.
const MAX_SNAP_DISTANCE := 3.0

static var _group_counter: int = 0

## Neue Ebenen automatisch mit Gegnern füllen.
@export var auto_populate: bool = false
## Elternknoten für Gegner. Leer = Level.get_active().actors, sonst der Elternknoten des Directors.
@export var actors_parent: Node3D

var pool: EnemyPool
var _spawn_counter: int = 0


func _ready() -> void:
	pool = EnemyPool.new()
	pool.name = "Pool"
	add_child(pool)
	EventBus.level_loaded.connect(_on_level_loaded)
	EventBus.level_unloading.connect(_on_level_unloading)


## Setzt einen einzelnen Gegner. elite = true würfelt Elite-Eigenschaften nach EliteRules.
func spawn(
	type: EnemyType,
	position: Vector3,
	level: int = 1,
	elite: bool = false,
	rng: RandomNumberGenerator = null
) -> Enemy:
	if rng == null:
		rng = _next_rng()
	var affixes: Array[EliteAffix] = []
	if elite:
		var rules := EliteRules.get_default()
		affixes = rules.roll_affixes(rules.affix_count(level), rng)
	return pool.acquire(type, get_actors_parent(), snap_to_navigation(position), level, affixes)


## Setzt einen Gegner mit festen Elite-Eigenschaften (Testszenen, Bosse).
func spawn_with_affixes(
	type: EnemyType, position: Vector3, level: int, affixes: Array[EliteAffix]
) -> Enemy:
	return pool.acquire(type, get_actors_parent(), snap_to_navigation(position), level, affixes)


## Setzt eine Gruppe um center. Mit elite = true führt das erste Mitglied als Elite-Gegner an.
func spawn_group(
	group: EnemySpawnGroup,
	center: Vector3,
	level: int = 1,
	elite: bool = false,
	rng: RandomNumberGenerator = null
) -> Array[Enemy]:
	if rng == null:
		rng = _next_rng()
	var types := group.roll_members(rng)
	return spawn_types(types, center, level, elite, rng, group.spacing)


## Setzt eine Liste von Typen als eine Gruppe (gemeinsames Bemerken).
func spawn_types(
	types: Array[EnemyType],
	center: Vector3,
	level: int = 1,
	elite: bool = false,
	rng: RandomNumberGenerator = null,
	spacing: float = 1.6
) -> Array[Enemy]:
	if rng == null:
		rng = _next_rng()
	_group_counter += 1
	var result: Array[Enemy] = []
	var spots := formation(center, types.size(), spacing, rng.randf() * TAU)
	for i in types.size():
		var enemy := spawn(types[i], spots[i], level, elite and i == 0, rng)
		enemy.group_id = _group_counter
		result.append(enemy)
	return result


## Füllt eine Ebene aus AP6: an jedem Spawnpunkt (Anteil fill_ratio) eine Gruppe.
func populate(
	layout: LevelLayout, table: EnemySpawnTable, rng: RandomNumberGenerator = null
) -> Array[Enemy]:
	var result: Array[Enemy] = []
	if layout == null or table == null:
		return result
	if rng == null:
		rng = Rng.make(hash([layout.seed, &"enemies"]))
	for point in layout.spawn_points:
		if rng.randf() > table.fill_ratio:
			continue
		var group := table.pick_group(rng)
		if group == null:
			continue
		var elite := rng.randf() < table.elite_chance
		result.append_array(spawn_group(group, point, table.level, elite, rng))
	return result


## Nimmt alle Gegner zurück in den Pool.
func clear() -> void:
	pool.release_all()


func get_enemies() -> Array[Enemy]:
	return pool.get_active()


## Lebende Gegner.
func get_alive() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for enemy in pool.get_active():
		if enemy.is_active():
			alive.append(enemy)
	return alive


func get_actors_parent() -> Node:
	if actors_parent != null and is_instance_valid(actors_parent):
		return actors_parent
	var level := Level.get_active()
	if level != null and level.actors != null:
		return level.actors
	return get_parent()


static func load_spawn_table(depth: int) -> EnemySpawnTable:
	var path := SPAWN_TABLE_PATH % depth
	if not ResourceLoader.exists(path):
		return null
	return load(path) as EnemySpawnTable


## Punkte für count Gruppenmitglieder: einer in der Mitte, die anderen auf Ringen darum.
static func formation(center: Vector3, count: int, spacing: float, angle: float) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	if count <= 0:
		return spots
	spots.append(center)
	var ring := 1
	while spots.size() < count:
		var on_ring := 6 * ring
		for i in on_ring:
			if spots.size() >= count:
				break
			var a := angle + TAU * i / on_ring
			spots.append(center + Vector3(cos(a), 0, sin(a)) * spacing * ring)
		ring += 1
	return spots


## Zieht einen Punkt auf das nächste Stück Navigationsnetz. Ohne Netz in der Nähe bleibt er,
## wie er ist (zum Beispiel in Tests ohne Navigation).
func snap_to_navigation(point: Vector3) -> Vector3:
	var map := _navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return point
	var closest := NavigationServer3D.map_get_closest_point(map, point)
	if Vector2(closest.x - point.x, closest.z - point.z).length() > MAX_SNAP_DISTANCE:
		return point
	return Vector3(closest.x, point.y, closest.z)


func _is_on_navigation(point: Vector3) -> bool:
	var map := _navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var closest := NavigationServer3D.map_get_closest_point(map, point)
	return Vector2(closest.x - point.x, closest.z - point.z).length() < 1.0


func _navigation_map() -> RID:
	var viewport := get_viewport()
	var world := viewport.find_world_3d() if viewport != null else null
	return world.navigation_map if world != null else RID()


func _next_rng() -> RandomNumberGenerator:
	_spawn_counter += 1
	return Rng.stream(&"enemy_spawn", _spawn_counter)


func _on_level_loaded(layout: LevelLayout) -> void:
	if not auto_populate:
		return
	_populate_when_navigation_ready(layout)


## Das Navigationsnetz einer neuen Ebene ist erst nach ein paar Physik-Takten auf der Karte.
## Vorher ließen sich Spawnpunkte nicht auf das Netz ziehen und Gruppenmitglieder landeten in
## Wänden. Gewartet wird, bis ein Spawnpunkt der Ebene tatsächlich auf dem Netz liegt.
func _populate_when_navigation_ready(layout: LevelLayout) -> void:
	if not layout.spawn_points.is_empty():
		var probe := layout.spawn_points[0]
		for i in NAVIGATION_WAIT_FRAMES:
			if _is_on_navigation(probe):
				break
			await get_tree().physics_frame
	var level := Level.get_active()
	if level != null and level.layout != layout:
		return
	populate(layout, load_spawn_table(layout.depth))


func _on_level_unloading(_layout: LevelLayout) -> void:
	clear()
