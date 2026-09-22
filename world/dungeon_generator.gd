class_name DungeonGenerator
extends RefCounted
## Erzeugt eine Dungeon-Ebene aus Raumvorlagen (RoomTemplate).
##
## Ablauf:
## 1. Startraum bei (0, 0) setzen.
## 2. Weitere Räume wachsen als Baum: an einen vorhandenen Raum in eine der vier Richtungen,
##    verbunden über einen geraden Gang. Räume und Gänge dürfen sich nicht berühren.
## 3. Einige zusätzliche Gänge zwischen nahen Räumen erzeugen Schleifen.
## 4. Wände, Türöffnungen, Treppen, Lichter, Requisiten und Spawnpunkte setzen.
##
## Gleicher Seed und gleiche LevelConfig ergeben immer dasselbe Layout.

const CELL_SIZE := Vector3(4, 4, 4)
const MIN_GAP := 2
const MAX_GAP := 6
const MAX_LOOP_GAP := 9
const ATTEMPTS_PER_ROOM := 80
## Anteil Bodenzellen am Raumrand, die eine zufällige Requisite bekommen.
const PROP_CHANCE := 0.14
const COBWEB_CHANCE := 0.45
const BANNER_CHANCE := 0.06
const LIGHT_HEIGHT_TORCH := 2.6
const LIGHT_HEIGHT_BRAZIER := 1.4
## Wie weit eine Wandfackel von der Zellmitte zur Wand hin sitzt (Meter).
const TORCH_WALL_OFFSET := 1.6

## Zufällige Requisiten mit Gewicht.
const RANDOM_PROPS: Dictionary[int, float] = {
	WorldTiles.Id.PROP_BARREL: 3.0,
	WorldTiles.Id.PROP_CRATE: 2.0,
	WorldTiles.Id.PROP_BONES: 3.0,
	WorldTiles.Id.PROP_CANDLES: 2.0,
	WorldTiles.Id.PROP_COFFIN: 1.5,
	WorldTiles.Id.PROP_RUBBLE: 1.5,
	WorldTiles.Id.PROP_TABLE: 0.7,
	WorldTiles.Id.PROP_CHEST: 0.4,
}

var _rng := RandomNumberGenerator.new()
var _config: LevelConfig
var _templates: Array[RoomTemplate] = []

var _rooms: Array[Rect2i] = []
var _patterns: Array[PackedStringArray] = []
var _room_kinds: Array[RoomTemplate.Kind] = []
var _links: Array[Vector2i] = []
## Begehbare Zellen → Tile-ID.
var _walk: Dictionary[Vector2i, int] = {}
var _orient: Dictionary[Vector2i, int] = {}
var _pillars: Dictionary[Vector2i, bool] = {}
var _walls: Dictionary[Vector2i, int] = {}
var _props: Dictionary[Vector2i, int] = {}
var _prop_orient: Dictionary[Vector2i, int] = {}
## Zellen, die für Räume und Gänge belegt sind (inklusive Wandring und Abstand).
var _reserved: Dictionary[Vector2i, bool] = {}
## Zelle → Raum-Index (nur Rauminneres).
var _room_of: Dictionary[Vector2i, int] = {}
## Türöffnung → Raum-Index, zu dem sie gehört.
var _doorways: Dictionary[Vector2i, int] = {}
## Gangzellen (ohne Türöffnungen).
var _corridors: Array[PackedVector2Array] = []
## Zeichen aus der Vorlage an Zellen mit Sonderbedeutung (S, p, L, B, C, O).
var _marks: Dictionary[Vector2i, String] = {}
## Zellen, die frei bleiben müssen (Treppen, Start, Marker).
var _keep_free: Dictionary[Vector2i, bool] = {}


## Erzeugt eine Ebene. templates: alle verfügbaren Vorlagen (gefiltert wird hier).
static func generate_layout(
	p_seed: int, config: LevelConfig, templates: Array[RoomTemplate]
) -> LevelLayout:
	var generator := DungeonGenerator.new()
	return generator.generate(p_seed, config, templates)


## Begehbare Zellen eines Layouts (für Tests, Minikarte und Navigation):
## Zellen mit begehbarem Tile ohne versperrende Requisite.
static func walkable_cells(layout: LevelLayout) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for cell in layout.cells:
		if cell.y != 0 or not WorldTiles.is_walkable_cell(layout.cells[cell]):
			continue
		if WorldTiles.is_blocking_prop(layout.props.get(cell, -1)):
			continue
		result[Vector2i(cell.x, cell.z)] = true
	return result


func generate(p_seed: int, config: LevelConfig, templates: Array[RoomTemplate]) -> LevelLayout:
	_config = config if config != null else LevelConfig.new()
	_rng.seed = hash([p_seed, _config.depth, _config.room_count, _config.is_boss_level])
	for template in templates:
		if _config.depth >= template.min_depth and _config.depth <= template.max_depth:
			_templates.append(template)
	if _config.is_boss_level:
		_place_boss_rooms()
	else:
		_place_rooms(maxi(_config.room_count, 2))
		_add_loops()
	_build_walls()
	var layout := LevelLayout.new()
	layout.seed = p_seed
	layout.depth = _config.depth
	layout.theme = _config.theme
	layout.cell_size = CELL_SIZE
	layout.rooms = _rooms.duplicate()
	layout.room_links = _links.duplicate()
	_place_entrance(layout)
	if _config.is_boss_level:
		_place_boss_markers(layout)
	else:
		_place_exit(layout)
	_place_lights(layout)
	_place_props()
	_place_spawns(layout)
	_write_cells(layout)
	return layout


# --- Räume setzen -------------------------------------------------------------------------


func _place_rooms(count: int) -> void:
	_add_room(_pick_pattern(RoomTemplate.Kind.ROOM), Vector2i.ZERO, RoomTemplate.Kind.ROOM)
	var attempts := 0
	while _rooms.size() < count and attempts < count * ATTEMPTS_PER_ROOM:
		attempts += 1
		var parent := _pick_parent()
		var dir: Vector2i = WorldTiles.DIRECTIONS[_rng.randi_range(0, 3)]
		_try_grow(parent, _pick_pattern(RoomTemplate.Kind.ROOM), dir, RoomTemplate.Kind.ROOM)


func _place_boss_rooms() -> void:
	_add_room(_pick_pattern(RoomTemplate.Kind.ROOM, 6), Vector2i.ZERO, RoomTemplate.Kind.ROOM)
	var boss_pattern := _pick_pattern(RoomTemplate.Kind.BOSS)
	for _attempt in ATTEMPTS_PER_ROOM:
		var dir: Vector2i = WorldTiles.DIRECTIONS[_rng.randi_range(0, 3)]
		if _try_grow(0, boss_pattern, dir, RoomTemplate.Kind.BOSS):
			return
	push_error("DungeonGenerator: Bossraum passt nicht.")


## Raum mit wenigen Verbindungen bevorzugen, damit der Baum in die Breite wächst.
func _pick_parent() -> int:
	var weights := PackedFloat32Array()
	for i in _rooms.size():
		var degree := 0
		for link in _links:
			if link.x == i or link.y == i:
				degree += 1
		weights.append(1.0 / float(1 + degree * degree) + (0.5 if i == _rooms.size() - 1 else 0.0))
	return _rng.rand_weighted(weights)


## Wählt eine Vorlage nach Gewicht und dreht oder spiegelt sie zufällig.
func _pick_pattern(kind: RoomTemplate.Kind, max_side: int = 999) -> PackedStringArray:
	var candidates: Array[RoomTemplate] = []
	var weights := PackedFloat32Array()
	for template in _templates:
		var size := template.get_size()
		if template.kind == kind and maxi(size.x, size.y) <= max_side:
			candidates.append(template)
			weights.append(template.weight)
	if candidates.is_empty():
		push_error("DungeonGenerator: keine Vorlage für Art %d." % kind)
		return PackedStringArray(["...", "...", "..."])
	var template := candidates[_rng.rand_weighted(weights)]
	if not template.allow_transform:
		return template.pattern
	return template.transformed(_rng.randi_range(0, 3), _rng.randf() < 0.5)


## Versucht, einen neuen Raum in Richtung dir an parent zu hängen.
func _try_grow(
	parent: int, pattern: PackedStringArray, dir: Vector2i, kind: RoomTemplate.Kind
) -> bool:
	var parent_edge := _edge_cells(_rooms[parent], _patterns[parent], dir)
	var size := Vector2i(pattern[0].length(), pattern.size())
	var own_edge := _edge_cells(Rect2i(Vector2i.ZERO, size), pattern, -dir)
	if parent_edge.is_empty() or own_edge.is_empty():
		return false
	var start: Vector2i = parent_edge[_rng.randi_range(0, parent_edge.size() - 1)]
	var local: Vector2i = own_edge[_rng.randi_range(0, own_edge.size() - 1)]
	var gap := _rng.randi_range(MIN_GAP, MAX_GAP)
	var rect := Rect2i(start + dir * (gap + 1) - local, size)
	if _is_reserved(rect.grow(1)) or not _corridor_free(start, dir, gap):
		return false
	var index := _add_room(pattern, rect.position, kind)
	_add_corridor(start, dir, gap, parent, index)
	return true


func _add_room(pattern: PackedStringArray, origin: Vector2i, kind: RoomTemplate.Kind) -> int:
	var index := _rooms.size()
	var rect := Rect2i(origin, Vector2i(pattern[0].length(), pattern.size()))
	_rooms.append(rect)
	_patterns.append(pattern)
	_room_kinds.append(kind)
	for z in rect.size.y:
		for x in rect.size.x:
			var cell := origin + Vector2i(x, z)
			var c := pattern[z][x]
			_room_of[cell] = index
			match c:
				"#":
					pass
				"P":
					_pillars[cell] = true
				"O":
					_walk[cell] = WorldTiles.Id.PORTAL
				_:
					_walk[cell] = _floor_tile(kind, c == ",")
					_orient[cell] = WorldTiles.ROTATIONS[_rng.randi_range(0, 3)]
			if c in "SpLBCO":
				_marks[cell] = c
	_reserve_rect(rect.grow(1))
	return index


func _floor_tile(kind: RoomTemplate.Kind, variant: bool) -> int:
	if kind == RoomTemplate.Kind.BOSS:
		return WorldTiles.Id.FLOOR_BOSS
	if variant:
		return WorldTiles.Id.FLOOR_CRACKED if _rng.randf() < 0.6 else WorldTiles.Id.FLOOR_RUBBLE
	var roll := _rng.randf()
	if roll < 0.1:
		return WorldTiles.Id.FLOOR_CRACKED
	if roll < 0.14:
		return WorldTiles.Id.FLOOR_RUBBLE
	return WorldTiles.Id.FLOOR


## Randzellen eines Raums auf der Seite dir, an die ein Gang andocken darf
## (nur schlichter Boden, keine Marker).
static func _edge_cells(rect: Rect2i, pattern: PackedStringArray, dir: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for z in rect.size.y:
		for x in rect.size.x:
			var on_edge := (
				(dir.x == 1 and x == rect.size.x - 1)
				or (dir.x == -1 and x == 0)
				or (dir.y == 1 and z == rect.size.y - 1)
				or (dir.y == -1 and z == 0)
			)
			if on_edge and pattern[z][x] in ".,S":
				result.append(rect.position + Vector2i(x, z))
	return result


# --- Gänge ------------------------------------------------------------------------------


## Prüft, ob ein gerader Gang von start (Randzelle eines Raums) in Richtung dir mit gap Zellen
## frei ist. Die erste und letzte Gangzelle liegen im Wandring der Räume (Türöffnungen).
func _corridor_free(start: Vector2i, dir: Vector2i, gap: int) -> bool:
	var side := Vector2i(dir.y, dir.x)
	for k in range(1, gap + 1):
		var cell := start + dir * k
		if _walk.has(cell) or _pillars.has(cell):
			return false
		if k == 1 or k == gap:
			# Türöffnung: keine zweite Öffnung direkt daneben.
			if _doorways.has(cell + side) or _doorways.has(cell - side):
				return false
			continue
		for probe: Vector2i in [cell, cell + side, cell - side]:
			if _reserved.has(probe):
				return false
	return true


func _add_corridor(start: Vector2i, dir: Vector2i, gap: int, room_a: int, room_b: int) -> void:
	var side := Vector2i(dir.y, dir.x)
	var cells := PackedVector2Array()
	for k in range(1, gap + 1):
		var cell := start + dir * k
		if k == 1 or k == gap:
			_walk[cell] = WorldTiles.Id.DOORWAY
			_orient[cell] = WorldTiles.orientation_facing(dir)
			_doorways[cell] = room_a if k == 1 else room_b
		else:
			_walk[cell] = _floor_tile(RoomTemplate.Kind.ROOM, false)
			_orient[cell] = WorldTiles.ROTATIONS[_rng.randi_range(0, 3)]
			cells.append(Vector2(cell))
		for probe: Vector2i in [cell, cell + side, cell - side]:
			_reserved[probe] = true
	_corridors.append(cells)
	_links.append(Vector2i(room_a, room_b))


## Zusätzliche Gänge zwischen Räumen, die nah beieinander liegen (Schleifen).
func _add_loops() -> void:
	var max_loops := maxi(1, floori(_rooms.size() / 3.0))
	var added := 0
	for a in _rooms.size():
		for b in _rooms.size():
			if a == b or added >= max_loops or _linked(a, b):
				continue
			for dir in WorldTiles.DIRECTIONS:
				var gap := _gap_between(_rooms[a], _rooms[b], dir)
				if gap < MIN_GAP or gap > MAX_LOOP_GAP:
					continue
				var starts := _edge_cells(_rooms[a], _patterns[a], dir)
				var options: Array[Vector2i] = []
				for start in starts:
					var target := start + dir * (gap + 1)
					var usable: bool = _room_of.get(target, -1) == b and _walk.has(target)
					if (
						usable
						and _marks.get(target, "S") == "S"
						and _corridor_free(start, dir, gap)
					):
						options.append(start)
				if not options.is_empty() and _rng.randf() < 0.6:
					_add_corridor(options[_rng.randi_range(0, options.size() - 1)], dir, gap, a, b)
					added += 1
					break


func _linked(a: int, b: int) -> bool:
	return _links.has(Vector2i(a, b)) or _links.has(Vector2i(b, a))


## Abstand der Innenflächen zweier Räume in Richtung dir, ausgedrückt als Ganglänge
## (Anzahl Zellen zwischen den Rändern). -1, wenn b nicht in dieser Richtung liegt.
static func _gap_between(a: Rect2i, b: Rect2i, dir: Vector2i) -> int:
	match dir:
		Vector2i(1, 0):
			return b.position.x - a.end.x
		Vector2i(-1, 0):
			return a.position.x - b.end.x
		Vector2i(0, 1):
			return b.position.y - a.end.y
		Vector2i(0, -1):
			return a.position.y - b.end.y
	return -1


func _is_reserved(rect: Rect2i) -> bool:
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if _reserved.has(Vector2i(x, z)):
				return true
	return false


func _reserve_rect(rect: Rect2i) -> void:
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_reserved[Vector2i(x, z)] = true


# --- Wände ------------------------------------------------------------------------------


func _build_walls() -> void:
	var candidates: Dictionary[Vector2i, bool] = {}
	for cell in _walk:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var next := cell + Vector2i(dx, dz)
				if not _walk.has(next) and not _pillars.has(next):
					candidates[next] = true
	for cell in candidates:
		_classify_wall(cell)


## Wählt das Wandstück nach den begehbaren Nachbarn und dreht es passend.
func _classify_wall(cell: Vector2i) -> void:
	var open: Array[Vector2i] = []
	for dir in WorldTiles.DIRECTIONS:
		if _walk.has(cell + dir):
			open.append(dir)
	var tile := WorldTiles.Id.WALL
	var orientation := 0
	match open.size():
		0:
			tile = WorldTiles.Id.WALL_CORNER
			for diagonal: Vector2i in [
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, -1), Vector2i(-1, 1)
			]:
				if _walk.has(cell + diagonal):
					orientation = WorldTiles.orientation_for_diagonal(diagonal)
					break
		1:
			orientation = WorldTiles.orientation_facing(open[0])
		2:
			if open[0] + open[1] == Vector2i.ZERO:
				tile = WorldTiles.Id.WALL_DOUBLE
				orientation = WorldTiles.orientation_facing(open[0])
			else:
				tile = WorldTiles.Id.WALL_CORNER_OUTER
				orientation = WorldTiles.orientation_for_diagonal(open[0] + open[1])
		3:
			tile = WorldTiles.Id.WALL_END
			for dir in WorldTiles.DIRECTIONS:
				if not dir in open:
					orientation = WorldTiles.orientation_facing(-dir)
		_:
			tile = WorldTiles.Id.PILLAR
	_walls[cell] = tile
	_orient[cell] = orientation


# --- Treppen, Boss, Marker --------------------------------------------------------------


## Treppe nach oben im Startraum an der Wand, möglichst weit weg von Türöffnungen.
## Der Spieler startet eine Zelle davor.
func _place_entrance(layout: LevelLayout) -> void:
	var spot := _stairs_spot(0)
	if spot.is_empty():
		var center := _nearest_free_cell(0, _rooms[0].get_center())
		layout.player_start = WorldTiles.cell_center(center, CELL_SIZE)
		_keep_free[center] = true
		return
	var cell: Vector2i = spot[0]
	var wall_dir: Vector2i = spot[1]
	_walk[cell] = WorldTiles.Id.STAIRS_UP
	_orient[cell] = WorldTiles.orientation_facing(-wall_dir)
	_keep_free[cell] = true
	_keep_free[cell - wall_dir] = true
	layout.entrance = WorldTiles.cell_center(cell, CELL_SIZE)
	layout.player_start = WorldTiles.cell_center(cell - wall_dir, CELL_SIZE)
	layout.markers[&"entrance_arrival"] = layout.player_start


## Treppe nach unten im Raum, der im Raumgraphen am weitesten vom Start entfernt ist.
func _place_exit(layout: LevelLayout) -> void:
	var distances := _room_distances()
	var far_room := 0
	for i in _rooms.size():
		if distances[i] >= distances[far_room]:
			far_room = i
	var spot := _stairs_spot(far_room)
	if spot.is_empty():
		var cell := _nearest_free_cell(far_room, _rooms[far_room].get_center())
		_walk[cell] = WorldTiles.Id.STAIRS_DOWN
		_keep_free[cell] = true
		layout.exits.append(WorldTiles.cell_center(cell, CELL_SIZE))
		layout.markers[&"exit_arrival"] = layout.exits[0]
		return
	var stairs: Vector2i = spot[0]
	var wall_dir: Vector2i = spot[1]
	_walk[stairs] = WorldTiles.Id.STAIRS_DOWN
	_orient[stairs] = WorldTiles.orientation_facing(-wall_dir)
	_keep_free[stairs] = true
	_keep_free[stairs - wall_dir] = true
	layout.exits.append(WorldTiles.cell_center(stairs, CELL_SIZE))
	layout.markers[&"exit_arrival"] = WorldTiles.cell_center(stairs - wall_dir, CELL_SIZE)


func _place_boss_markers(layout: LevelLayout) -> void:
	var boss := _rooms.size() - 1
	layout.boss_room = boss
	layout.markers[&"boss_room_center"] = _room_center_world(boss)
	for cell in _marks:
		if _room_of.get(cell, -1) != boss:
			continue
		match _marks[cell]:
			"B":
				layout.markers[&"boss_spawn"] = WorldTiles.cell_center(cell, CELL_SIZE)
			"C":
				layout.markers[&"boss_chest"] = WorldTiles.cell_center(cell, CELL_SIZE)
			"O":
				layout.markers[&"portal"] = WorldTiles.cell_center(cell, CELL_SIZE)
		_keep_free[cell] = true
	for cell in _doorways:
		if _doorways[cell] == boss:
			layout.markers[&"boss_gate"] = WorldTiles.cell_center(cell, CELL_SIZE)


## Sucht eine Randzelle mit Wand dahinter (keine Türöffnung). Liefert [Zelle, Richtung zur Wand]
## oder [] wenn keine passt.
func _stairs_spot(room: int) -> Array:
	var rect := _rooms[room]
	var best: Array = []
	var best_score := -1
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, z)
			if _walk.get(cell, -1) not in [WorldTiles.Id.FLOOR, WorldTiles.Id.FLOOR_CRACKED]:
				continue
			if _marks.has(cell) or _keep_free.has(cell):
				continue
			for dir in WorldTiles.DIRECTIONS:
				var behind := cell + dir
				var front := cell - dir
				if _walk.has(behind) or _pillars.has(behind) or _room_of.has(behind):
					continue
				if not _walk.has(front) or _marks.has(front) or _room_of.get(front, -1) != room:
					continue
				var score := _distance_to_doorways(cell, room)
				if score > best_score:
					best_score = score
					best = [cell, dir]
	return best


func _distance_to_doorways(cell: Vector2i, room: int) -> int:
	var best := 1000
	for door in _doorways:
		if _doorways[door] == room:
			best = mini(best, absi(door.x - cell.x) + absi(door.y - cell.y))
	return best


func _nearest_free_cell(room: int, target: Vector2i) -> Vector2i:
	var best := _rooms[room].position
	var best_distance := 1 << 30
	for cell in _room_of:
		if _room_of[cell] != room or not _walk.has(cell) or _marks.has(cell):
			continue
		var distance := (cell - target).length_squared()
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best


## Abstand jedes Raums vom Startraum in Anzahl Gängen (Breitensuche).
func _room_distances() -> Array[int]:
	var distances: Array[int] = []
	distances.resize(_rooms.size())
	distances.fill(-1)
	distances[0] = 0
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var room: int = queue.pop_front()
		for link in _links:
			var other := link.y if link.x == room else (link.x if link.y == room else -1)
			if other >= 0 and distances[other] < 0:
				distances[other] = distances[room] + 1
				queue.append(other)
	return distances


func _room_center_world(room: int) -> Vector3:
	var rect := _rooms[room]
	var center := Vector2(rect.position) + Vector2(rect.size) * 0.5
	return Vector3(center.x * CELL_SIZE.x, 0.0, center.y * CELL_SIZE.z)


# --- Licht und Requisiten ---------------------------------------------------------------


func _place_lights(layout: LevelLayout) -> void:
	for cell in _marks:
		if _marks[cell] == "L":
			_props[cell] = WorldTiles.Id.BRAZIER
			layout.lights.append(
				WorldTiles.cell_center(cell, CELL_SIZE) + Vector3(0, LIGHT_HEIGHT_BRAZIER, 0)
			)
	for room in _rooms.size():
		var rect := _rooms[room]
		var wanted := clampi((rect.size.x + rect.size.y) / 4, 1, 4)
		var spots := _wall_spots(room)
		for i in mini(wanted, spots.size()):
			var pick: Array = spots.pop_at(_rng.randi_range(0, spots.size() - 1))
			_add_torch(layout, pick[0], pick[1])
	for corridor in _corridors:
		if corridor.size() >= 4:
			var cell := Vector2i(corridor[corridor.size() / 2])
			for dir in WorldTiles.DIRECTIONS:
				if _walls.get(cell + dir, -1) == WorldTiles.Id.WALL and not _props.has(cell):
					_add_torch(layout, cell, dir)
					break


func _add_torch(layout: LevelLayout, cell: Vector2i, wall_dir: Vector2i) -> void:
	_props[cell] = WorldTiles.Id.TORCH_WALL
	_prop_orient[cell] = WorldTiles.orientation_facing(-wall_dir)
	var offset := Vector3(wall_dir.x, 0, wall_dir.y) * TORCH_WALL_OFFSET
	layout.lights.append(
		WorldTiles.cell_center(cell, CELL_SIZE) + offset + Vector3(0, LIGHT_HEIGHT_TORCH, 0)
	)


## Bodenzellen am Raumrand mit gerader Wand dahinter: [[Zelle, Richtung zur Wand], …].
func _wall_spots(room: int) -> Array:
	var spots: Array = []
	var rect := _rooms[room]
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, z)
			if not _walk.has(cell) or _props.has(cell) or _near_doorway(cell):
				continue
			for dir in WorldTiles.DIRECTIONS:
				if _walls.get(cell + dir, -1) == WorldTiles.Id.WALL:
					spots.append([cell, dir])
					break
	return spots


func _near_doorway(cell: Vector2i) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if _doorways.has(cell + Vector2i(dx, dz)):
				return true
	return false


func _place_props() -> void:
	var prop_ids: Array[int] = []
	var prop_weights := PackedFloat32Array()
	for id in RANDOM_PROPS:
		prop_ids.append(id)
		prop_weights.append(RANDOM_PROPS[id])
	var cells: Array[Vector2i] = []
	cells.assign(_room_of.keys())
	cells.sort()
	for cell in cells:
		if not _walk.has(cell) or _props.has(cell) or _keep_free.has(cell):
			continue
		if (
			_walk[cell]
			in [WorldTiles.Id.PORTAL, WorldTiles.Id.STAIRS_UP, WorldTiles.Id.STAIRS_DOWN]
		):
			continue
		var mark: String = _marks.get(cell, "")
		if mark in ["S", "B", "C", "O"] or _near_doorway(cell):
			continue
		var walls := _adjacent_walls(cell)
		var corner := _corner_diagonal(walls)
		if mark == "p" or (not walls.is_empty() and _rng.randf() < PROP_CHANCE):
			var id := prop_ids[_rng.rand_weighted(prop_weights)]
			if WorldTiles.is_blocking_prop(id) and not _can_block(cell):
				id = WorldTiles.Id.PROP_BONES
			_props[cell] = id
			_prop_orient[cell] = (
				WorldTiles.orientation_facing(-walls[0])
				if not walls.is_empty()
				else WorldTiles.ROTATIONS[_rng.randi_range(0, 3)]
			)
		elif corner != Vector2i.ZERO and _rng.randf() < COBWEB_CHANCE:
			_props[cell] = WorldTiles.Id.PROP_COBWEB
			_prop_orient[cell] = WorldTiles.orientation_for_diagonal(-corner)
		elif walls.size() == 1 and _rng.randf() < BANNER_CHANCE:
			_props[cell] = WorldTiles.Id.PROP_BANNER
			_prop_orient[cell] = WorldTiles.orientation_facing(-walls[0])


## Richtungen, in denen direkt eine Wand (kein Gang, keine Säule) liegt.
func _adjacent_walls(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in WorldTiles.DIRECTIONS:
		if _walls.has(cell + dir):
			result.append(dir)
	return result


## Diagonale zur Raumecke, wenn zwei rechtwinklige Wände anliegen, sonst ZERO.
static func _corner_diagonal(walls: Array[Vector2i]) -> Vector2i:
	if walls.size() == 2 and walls[0] + walls[1] != Vector2i.ZERO:
		return walls[0] + walls[1]
	return Vector2i.ZERO


## Darf die Zelle versperrt werden, ohne die Nachbarn voneinander zu trennen?
## Prüft, ob die begehbaren Nachbarn (8er-Umgebung) untereinander verbunden bleiben.
func _can_block(cell: Vector2i) -> bool:
	var around: Array[Vector2i] = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var next := cell + Vector2i(dx, dz)
			if next != cell and _is_open(next):
				around.append(next)
	if around.is_empty():
		return false
	var seen := {around[0]: true}
	var queue: Array[Vector2i] = [around[0]]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_back()
		for dir in WorldTiles.DIRECTIONS:
			var next: Vector2i = current + dir
			if next in around and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen.size() == around.size()


func _is_open(cell: Vector2i) -> bool:
	return _walk.has(cell) and not WorldTiles.is_blocking_prop(_props.get(cell, -1))


func _place_spawns(layout: LevelLayout) -> void:
	for room in _rooms.size():
		if room == 0 or _room_kinds[room] == RoomTemplate.Kind.BOSS:
			continue
		var marked: Array[Vector2i] = []
		var free: Array[Vector2i] = []
		var rect := _rooms[room]
		for z in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, z)
				if not _is_open(cell) or _keep_free.has(cell) or _doorways.has(cell):
					continue
				if _marks.get(cell, "") == "S":
					marked.append(cell)
				elif not _props.has(cell):
					free.append(cell)
		var area := marked.size() + free.size()
		var wanted := clampi(area / 10 + (_config.depth - 1), 2, 6)
		while marked.size() < wanted and not free.is_empty():
			marked.append(free.pop_at(_rng.randi_range(0, free.size() - 1)))
		for cell in marked:
			layout.spawn_points.append(WorldTiles.cell_center(cell, CELL_SIZE))
			layout.spawn_rooms.append(room)


func _write_cells(layout: LevelLayout) -> void:
	var min_cell := Vector2i(1 << 30, 1 << 30)
	var max_cell := -min_cell
	for source: Dictionary in [_walk, _walls]:
		for cell: Vector2i in source:
			layout.cells[Vector3i(cell.x, 0, cell.y)] = source[cell]
			min_cell = min_cell.min(cell)
			max_cell = max_cell.max(cell)
	for cell in _pillars:
		layout.cells[Vector3i(cell.x, 0, cell.y)] = WorldTiles.Id.PILLAR
	for cell in _orient:
		if _orient[cell] != 0 and layout.cells.has(Vector3i(cell.x, 0, cell.y)):
			layout.cell_orientations[Vector3i(cell.x, 0, cell.y)] = _orient[cell]
	for cell in _props:
		layout.props[Vector3i(cell.x, 0, cell.y)] = _props[cell]
		if _prop_orient.get(cell, 0) != 0:
			layout.prop_orientations[Vector3i(cell.x, 0, cell.y)] = _prop_orient[cell]
	var origin := Vector3(min_cell.x * CELL_SIZE.x, 0, min_cell.y * CELL_SIZE.z)
	var extent := Vector3(
		(max_cell.x - min_cell.x + 1) * CELL_SIZE.x,
		CELL_SIZE.y,
		(max_cell.y - min_cell.y + 1) * CELL_SIZE.z
	)
	layout.bounds = AABB(origin, extent)
