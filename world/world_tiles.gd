class_name WorldTiles
## Zellnamen und IDs des Baukastens (Absprache mit AP8, siehe docs/pakete/AP6.md).
## IDs werden in LevelLayout.cells und LevelLayout.props gespeichert. Neue Einträge nur am Ende.

enum Id {
	FLOOR = 0,
	FLOOR_CRACKED = 1,
	FLOOR_RUBBLE = 2,
	WALL = 3,
	WALL_CORNER = 4,
	WALL_CORNER_OUTER = 5,
	WALL_DOUBLE = 6,
	WALL_END = 7,
	DOORWAY = 8,
	PILLAR = 9,
	STAIRS_DOWN = 10,
	STAIRS_UP = 11,
	FLOOR_BOSS = 12,
	PORTAL = 13,
	PROP_BARREL = 20,
	PROP_CRATE = 21,
	PROP_BONES = 22,
	PROP_CANDLES = 23,
	PROP_COFFIN = 24,
	PROP_RUBBLE = 25,
	PROP_TABLE = 26,
	PROP_BANNER = 27,
	TORCH_WALL = 28,
	BRAZIER = 29,
	PROP_CHEST = 30,
	PROP_COBWEB = 31,
	GROUND_GRASS = 40,
	GROUND_PATH = 41,
	GROUND_DIRT = 42,
	HOUSE_WALL = 43,
	HOUSE_CORNER = 44,
	HOUSE_DOOR = 45,
	FENCE = 46,
	TREE = 47,
	ROCK = 48,
	WELL = 49,
	LAMP_POST = 50,
	MARKET_STALL = 51,
	CRYPT_ENTRANCE = 52,
	HOUSE_ROOF = 53,
}

## Name des Items in der MeshLibrary je ID.
const NAMES: Dictionary[int, String] = {
	Id.FLOOR: "floor",
	Id.FLOOR_CRACKED: "floor_cracked",
	Id.FLOOR_RUBBLE: "floor_rubble",
	Id.WALL: "wall",
	Id.WALL_CORNER: "wall_corner",
	Id.WALL_CORNER_OUTER: "wall_corner_outer",
	Id.WALL_DOUBLE: "wall_double",
	Id.WALL_END: "wall_end",
	Id.DOORWAY: "doorway",
	Id.PILLAR: "pillar",
	Id.STAIRS_DOWN: "stairs_down",
	Id.STAIRS_UP: "stairs_up",
	Id.FLOOR_BOSS: "floor_boss",
	Id.PORTAL: "portal",
	Id.PROP_BARREL: "prop_barrel",
	Id.PROP_CRATE: "prop_crate",
	Id.PROP_BONES: "prop_bones",
	Id.PROP_CANDLES: "prop_candles",
	Id.PROP_COFFIN: "prop_coffin",
	Id.PROP_RUBBLE: "prop_rubble",
	Id.PROP_TABLE: "prop_table",
	Id.PROP_BANNER: "prop_banner",
	Id.TORCH_WALL: "torch_wall",
	Id.BRAZIER: "brazier",
	Id.PROP_CHEST: "prop_chest",
	Id.PROP_COBWEB: "prop_cobweb",
	Id.GROUND_GRASS: "ground_grass",
	Id.GROUND_PATH: "ground_path",
	Id.GROUND_DIRT: "ground_dirt",
	Id.HOUSE_WALL: "house_wall",
	Id.HOUSE_CORNER: "house_corner",
	Id.HOUSE_DOOR: "house_door",
	Id.FENCE: "fence",
	Id.TREE: "tree",
	Id.ROCK: "rock",
	Id.WELL: "well",
	Id.LAMP_POST: "lamp_post",
	Id.MARKET_STALL: "market_stall",
	Id.CRYPT_ENTRANCE: "crypt_entrance",
	Id.HOUSE_ROOF: "house_roof",
}

## Zellen auf der Ebene cells, auf denen man laufen kann.
const WALKABLE_CELLS: Array[int] = [
	Id.FLOOR,
	Id.FLOOR_CRACKED,
	Id.FLOOR_RUBBLE,
	Id.DOORWAY,
	Id.STAIRS_DOWN,
	Id.STAIRS_UP,
	Id.FLOOR_BOSS,
	Id.PORTAL,
	Id.GROUND_GRASS,
	Id.GROUND_PATH,
	Id.GROUND_DIRT,
	Id.CRYPT_ENTRANCE,
]

## Requisiten, die den Weg versperren (Zelle fällt aus der Navigation).
const BLOCKING_PROPS: Array[int] = [
	Id.PROP_BARREL,
	Id.PROP_CRATE,
	Id.PROP_COFFIN,
	Id.PROP_RUBBLE,
	Id.PROP_TABLE,
	Id.BRAZIER,
	Id.PROP_CHEST,
	Id.FENCE,
	Id.TREE,
	Id.WELL,
	Id.LAMP_POST,
	Id.MARKET_STALL,
]

## Die vier Himmelsrichtungen im Raster (x, z).
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(-1, 0),
]

## GridMap-Orientierungsindex für 0°, 90°, 180° und 270° um die y-Achse.
## Werte aus GridMap.get_orthogonal_index_from_basis(), fest, damit Daten ohne Szenenbaum gehen.
const ROTATIONS: Array[int] = [0, 16, 10, 22]


static func tile_name(id: int) -> String:
	return NAMES.get(id, "")


static func is_walkable_cell(id: int) -> bool:
	return id in WALKABLE_CELLS


static func is_blocking_prop(id: int) -> bool:
	return id in BLOCKING_PROPS


## Orientierungsindex, der lokal +Z in die Rasterrichtung direction dreht.
static func orientation_facing(direction: Vector2i) -> int:
	var index := DIRECTIONS.find(direction)
	return ROTATIONS[maxi(index, 0)]


## Orientierungsindex, der die lokale Diagonale (+X, +Z) in die Rasterdiagonale diagonal dreht.
static func orientation_for_diagonal(diagonal: Vector2i) -> int:
	match diagonal:
		Vector2i(1, -1):
			return ROTATIONS[1]
		Vector2i(-1, -1):
			return ROTATIONS[2]
		Vector2i(-1, 1):
			return ROTATIONS[3]
	return ROTATIONS[0]


## Mitte einer Zelle in Weltkoordinaten (Bodenhöhe).
static func cell_center(cell: Vector2i, cell_size: Vector3) -> Vector3:
	return Vector3((cell.x + 0.5) * cell_size.x, 0.0, (cell.y + 0.5) * cell_size.z)


## Zelle unter einer Weltposition.
static func world_to_cell(position: Vector3, cell_size: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / cell_size.x), floori(position.z / cell_size.z))
