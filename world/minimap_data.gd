class_name MinimapData
extends RefCounted
## Daten für die Minikarte (AP7 zeichnet sie): ein Bild mit einem Pixel pro Zelle
## und Umrechnungen zwischen Welt und Bild. Aufgedeckte Bereiche verwaltet AP7.

const COLOR_EMPTY := Color(0, 0, 0, 0)
const COLOR_FLOOR := Color(0.55, 0.52, 0.48, 1)
const COLOR_WALL := Color(0.22, 0.2, 0.19, 1)
const COLOR_OBSTACLE := Color(0.35, 0.33, 0.3, 1)
const COLOR_EXIT := Color(0.9, 0.25, 0.2, 1)
const COLOR_ENTRANCE := Color(0.35, 0.8, 0.35, 1)
const COLOR_PORTAL := Color(0.35, 0.5, 1.0, 1)
const COLOR_GRASS := Color(0.25, 0.38, 0.2, 1)
const COLOR_HOUSE := Color(0.45, 0.3, 0.2, 1)

const TILE_COLORS: Dictionary[int, Color] = {
	WorldTiles.Id.STAIRS_DOWN: COLOR_EXIT,
	WorldTiles.Id.CRYPT_ENTRANCE: COLOR_EXIT,
	WorldTiles.Id.STAIRS_UP: COLOR_ENTRANCE,
	WorldTiles.Id.PORTAL: COLOR_PORTAL,
	WorldTiles.Id.GROUND_GRASS: COLOR_GRASS,
	WorldTiles.Id.HOUSE_WALL: COLOR_HOUSE,
	WorldTiles.Id.HOUSE_CORNER: COLOR_HOUSE,
	WorldTiles.Id.HOUSE_DOOR: COLOR_HOUSE,
	WorldTiles.Id.HOUSE_ROOF: COLOR_HOUSE,
}


## Bereich der Karte in Zellen (x, z).
static func cell_rect(layout: LevelLayout) -> Rect2i:
	var origin := WorldTiles.world_to_cell(layout.bounds.position, layout.cell_size)
	var size := Vector2i(
		roundi(layout.bounds.size.x / layout.cell_size.x),
		roundi(layout.bounds.size.z / layout.cell_size.z)
	)
	return Rect2i(origin, size)


## Bild mit einem Pixel pro Zelle. Pixel (0, 0) ist die Zelle cell_rect().position.
static func build_image(layout: LevelLayout) -> Image:
	var rect := cell_rect(layout)
	var image := Image.create_empty(
		maxi(rect.size.x, 1), maxi(rect.size.y, 1), false, Image.FORMAT_RGBA8
	)
	image.fill(COLOR_EMPTY)
	for cell in layout.cells:
		var pixel := Vector2i(cell.x, cell.z) - rect.position
		if pixel.x < 0 or pixel.y < 0 or pixel.x >= rect.size.x or pixel.y >= rect.size.y:
			continue
		image.set_pixelv(pixel, color_for(layout, cell))
	return image


static func color_for(layout: LevelLayout, cell: Vector3i) -> Color:
	var tile: int = layout.cells[cell]
	if TILE_COLORS.has(tile):
		return TILE_COLORS[tile]
	if not WorldTiles.is_walkable_cell(tile):
		return COLOR_WALL
	if WorldTiles.is_blocking_prop(layout.props.get(cell, -1)):
		return COLOR_OBSTACLE
	return COLOR_FLOOR


## Weltposition → Bildkoordinate (in Pixeln, mit Nachkommastellen für die Spielerposition).
static func world_to_pixel(layout: LevelLayout, position: Vector3) -> Vector2:
	var local := position - layout.bounds.position
	return Vector2(local.x / layout.cell_size.x, local.z / layout.cell_size.z)


## Bildkoordinate → Weltposition (Bodenhöhe).
static func pixel_to_world(layout: LevelLayout, pixel: Vector2) -> Vector3:
	return (
		layout.bounds.position
		+ Vector3(pixel.x * layout.cell_size.x, 0, pixel.y * layout.cell_size.z)
	)


## Index des Raums, in dem eine Weltposition liegt, oder -1 (Gang, Dorf).
static func room_at(layout: LevelLayout, position: Vector3) -> int:
	var cell := WorldTiles.world_to_cell(position, layout.cell_size)
	for i in layout.rooms.size():
		if layout.rooms[i].has_point(cell):
			return i
	return -1
