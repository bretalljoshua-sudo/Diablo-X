extends Node
## Autoload „World“. ERSATZVERSION aus AP0: liefert immer denselben flachen Testraum
## (20 × 20 m). AP6 ersetzt den Inhalt durch den Dungeon-Generator.
##
## Vertrag: generate(p_seed: int, config: LevelConfig) -> LevelLayout
##   Gleicher Seed und gleiche config ergeben immer dasselbe Layout.

const ROOM_HALF_SIZE := 10
const FLOOR_ITEM := 0


func generate(p_seed: int, config: LevelConfig) -> LevelLayout:
	var layout := LevelLayout.new()
	layout.seed = p_seed
	layout.player_start = Vector3.ZERO
	var size := float(ROOM_HALF_SIZE * 2)
	layout.bounds = AABB(Vector3(-ROOM_HALF_SIZE, 0, -ROOM_HALF_SIZE), Vector3(size, 3.0, size))
	for x in range(-ROOM_HALF_SIZE, ROOM_HALF_SIZE):
		for z in range(-ROOM_HALF_SIZE, ROOM_HALF_SIZE):
			layout.cells[Vector3i(x, 0, z)] = FLOOR_ITEM
	for corner: Vector2 in [Vector2(-6, -6), Vector2(6, -6), Vector2(-6, 6), Vector2(6, 6)]:
		layout.spawn_points.append(Vector3(corner.x, 0, corner.y))
		layout.lights.append(Vector3(corner.x * 0.8, 2.5, corner.y * 0.8))
	if config == null or not config.is_boss_level:
		layout.exits.append(Vector3(0, 0, -ROOM_HALF_SIZE + 1))
	return layout
