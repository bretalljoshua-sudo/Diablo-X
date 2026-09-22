class_name VillageMap
extends RefCounted
## Übersetzt eine feste Karte (FixedMap, zum Beispiel das Dorf) in ein LevelLayout.
## Das Ergebnis hängt nicht vom Seed ab, nur Bodendrehungen werden daraus gewürfelt.

const CELL_SIZE := Vector3(4, 4, 4)
const LAMP_HEIGHT := 3.0

const GROUND: Dictionary[String, int] = {
	",": WorldTiles.Id.GROUND_GRASS,
	".": WorldTiles.Id.GROUND_PATH,
	":": WorldTiles.Id.GROUND_DIRT,
}

## Requisiten auf Wiese oder Weg: Zeichen → [Requisite, Boden darunter].
const PROPS: Dictionary[String, Array] = {
	"T": [WorldTiles.Id.TREE, WorldTiles.Id.GROUND_GRASS],
	"F": [WorldTiles.Id.FENCE, WorldTiles.Id.GROUND_GRASS],
	"W": [WorldTiles.Id.WELL, WorldTiles.Id.GROUND_PATH],
	"l": [WorldTiles.Id.LAMP_POST, WorldTiles.Id.GROUND_PATH],
	"m": [WorldTiles.Id.MARKET_STALL, WorldTiles.Id.GROUND_PATH],
}

## Marker auf Weg: Zeichen → Name in LevelLayout.markers.
const MARKERS: Dictionary[String, StringName] = {
	"M": &"merchant",
	"C": &"stash",
	"a": &"exit_arrival",
}


static func generate(map: FixedMap, p_seed: int) -> LevelLayout:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([p_seed, map.id])
	var layout := LevelLayout.new()
	layout.seed = p_seed
	layout.depth = 0
	layout.theme = map.theme
	layout.cell_size = CELL_SIZE
	var size := Vector2i(map.pattern[0].length(), map.pattern.size())
	for z in size.y:
		for x in size.x:
			var cell := Vector2i(x, z)
			var key := Vector3i(x, 0, z)
			var c := map.pattern[z][x]
			var center := WorldTiles.cell_center(cell, CELL_SIZE)
			if GROUND.has(c):
				layout.cells[key] = GROUND[c]
				layout.cell_orientations[key] = WorldTiles.ROTATIONS[rng.randi_range(0, 3)]
			elif PROPS.has(c):
				layout.cells[key] = PROPS[c][1]
				layout.props[key] = PROPS[c][0]
				layout.prop_orientations[key] = _prop_orientation(map, cell, c, rng)
				if c == "l":
					layout.lights.append(center + Vector3(0, LAMP_HEIGHT, 0))
			elif MARKERS.has(c):
				layout.cells[key] = WorldTiles.Id.GROUND_PATH
				layout.markers[MARKERS[c]] = center
			elif c == "@":
				layout.cells[key] = WorldTiles.Id.GROUND_PATH
				layout.player_start = center
				layout.markers[&"entrance_arrival"] = center
			elif c == "E":
				layout.cells[key] = WorldTiles.Id.CRYPT_ENTRANCE
				layout.exits.append(center)
				layout.lights.append(center + Vector3(0, LAMP_HEIGHT, 1.5))
			elif c == "H" or c == "D":
				_house_cell(map, cell, c, layout)
			else:
				layout.cells[key] = WorldTiles.Id.ROCK
				layout.cell_orientations[key] = WorldTiles.ROTATIONS[rng.randi_range(0, 3)]
	layout.bounds = AABB(Vector3.ZERO, Vector3(size.x, 1, size.y) * CELL_SIZE)
	return layout


static func _char_at(map: FixedMap, cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= map.pattern.size() or cell.x < 0:
		return "R"
	if cell.x >= map.pattern[cell.y].length():
		return "R"
	return map.pattern[cell.y][cell.x]


## Hauszellen: Rand wird Wand oder Ecke (nach außen gedreht), Inneres wird Dach.
static func _house_cell(map: FixedMap, cell: Vector2i, c: String, layout: LevelLayout) -> void:
	var outside: Array[Vector2i] = []
	for dir in WorldTiles.DIRECTIONS:
		if not _char_at(map, cell + dir) in ["H", "D"]:
			outside.append(dir)
	var key := Vector3i(cell.x, 0, cell.y)
	if outside.is_empty():
		layout.cells[key] = WorldTiles.Id.HOUSE_ROOF
	elif c == "D" or outside.size() == 1:
		layout.cells[key] = WorldTiles.Id.HOUSE_DOOR if c == "D" else WorldTiles.Id.HOUSE_WALL
		layout.cell_orientations[key] = WorldTiles.orientation_facing(outside[0])
	else:
		layout.cells[key] = WorldTiles.Id.HOUSE_CORNER
		layout.cell_orientations[key] = WorldTiles.orientation_for_diagonal(outside[0] + outside[1])


## Zäune folgen der Linie ihrer Nachbarn, alles andere wird zufällig gedreht.
static func _prop_orientation(
	map: FixedMap, cell: Vector2i, c: String, rng: RandomNumberGenerator
) -> int:
	if c == "F":
		var vertical := _char_at(map, cell + Vector2i(0, 1)) == "F"
		vertical = vertical or _char_at(map, cell + Vector2i(0, -1)) == "F"
		return WorldTiles.ROTATIONS[1] if vertical else WorldTiles.ROTATIONS[0]
	if c == "m":
		return WorldTiles.ROTATIONS[0]
	return WorldTiles.ROTATIONS[rng.randi_range(0, 3)]
