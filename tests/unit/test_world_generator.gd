extends GutTest
## Tests für den Dungeon-Generator und das Dorf (AP6).

const SEED_COUNT := 1000


func _config(depth: int) -> LevelConfig:
	return World.config_for_depth(depth)


func test_templates_are_valid() -> void:
	var templates := World.get_templates()
	assert_gt(templates.size(), 8, "genug Raumvorlagen")
	var has_boss := false
	for template in templates:
		assert_eq(template.validate(), "", "Vorlage %s" % template.id)
		has_boss = has_boss or template.kind == RoomTemplate.Kind.BOSS
		for turns in 4:
			var rotated := template.transformed(turns, turns % 2 == 1)
			var copy := RoomTemplate.new()
			copy.id = template.id
			copy.kind = template.kind
			copy.pattern = rotated
			assert_eq(copy.validate(), "", "Vorlage %s gedreht %d" % [template.id, turns])
	assert_true(has_boss, "es gibt eine Bossraum-Vorlage")


func test_rotation_indices_match_gridmap() -> void:
	var grid: GridMap = autofree(GridMap.new())
	for i in 4:
		var basis := Basis(Vector3.UP, i * PI / 2.0)
		assert_eq(
			WorldTiles.ROTATIONS[i], grid.get_orthogonal_index_from_basis(basis), "Drehung %d" % i
		)
		var facing: Vector3 = (
			grid.get_basis_with_orthogonal_index(WorldTiles.ROTATIONS[i]) * Vector3.BACK
		)
		var dir := WorldTiles.DIRECTIONS[i]
		assert_almost_eq(
			facing, Vector3(dir.x, 0, dir.y), Vector3.ONE * 0.001, "+Z zeigt nach %s" % dir
		)


func test_same_seed_same_dungeon() -> void:
	for depth in [1, 2, 3]:
		var a := World.generate(1234, _config(depth))
		var b := World.generate(1234, _config(depth))
		assert_eq(a.cells, b.cells, "Zellen Ebene %d" % depth)
		assert_eq(a.cell_orientations, b.cell_orientations)
		assert_eq(a.props, b.props)
		assert_eq(a.spawn_points, b.spawn_points)
		assert_eq(a.exits, b.exits)
		assert_eq(a.lights, b.lights)
		assert_eq(a.rooms, b.rooms)
		assert_eq(a.player_start, b.player_start)


func test_different_seeds_differ() -> void:
	var a := World.generate(1, _config(1))
	var b := World.generate(2, _config(1))
	assert_ne(a.cells, b.cells)


func test_all_rooms_reachable_over_many_seeds() -> void:
	var failures: Array[String] = []
	for i in SEED_COUNT:
		var depth := 1 + i % 3
		var layout := World.generate(i * 7919 + 13, _config(depth))
		var problem := _check_layout(layout)
		if not problem.is_empty():
			failures.append("Seed %d, Ebene %d: %s" % [i * 7919 + 13, depth, problem])
	assert_eq(failures, [] as Array[String], "%d Seeds geprüft" % SEED_COUNT)


func test_room_counts_follow_config() -> void:
	for i in 50:
		assert_eq(World.generate(i, _config(1)).rooms.size(), _config(1).room_count)
		assert_eq(World.generate(i, _config(2)).rooms.size(), _config(2).room_count)
		assert_eq(World.generate(i, _config(3)).rooms.size(), 2)


func test_dungeon_level_has_stairs_spawns_and_lights() -> void:
	var layout := World.generate(99, _config(1))
	assert_eq(layout.exits.size(), 1)
	assert_ne(layout.entrance, Vector3.INF)
	assert_eq(layout.spawn_points.size(), layout.spawn_rooms.size())
	assert_gt(layout.spawn_points.size(), layout.rooms.size())
	assert_gt(layout.lights.size(), layout.rooms.size())
	assert_true(layout.markers.has(&"exit_arrival"))
	assert_false(0 in layout.spawn_rooms, "keine Gegner im Startraum")


func test_boss_level_markers() -> void:
	var layout := World.generate(5, _config(3))
	assert_eq(layout.boss_room, 1)
	assert_true(layout.exits.is_empty(), "Bossraum hat keine Treppe nach unten")
	for marker: StringName in [&"boss_spawn", &"boss_chest", &"portal", &"boss_gate"]:
		assert_true(layout.markers.has(marker), "Marker %s" % marker)
	var boss_cell := WorldTiles.world_to_cell(layout.markers[&"boss_spawn"], layout.cell_size)
	assert_true(layout.rooms[1].has_point(boss_cell), "Boss steht im Bossraum")


func test_village_is_fixed_and_complete() -> void:
	var a := World.generate(1, _config(0))
	var b := World.generate(2, _config(0))
	assert_eq(a.cells, b.cells, "Dorf hängt nicht vom Seed ab")
	assert_eq(a.depth, 0)
	assert_eq(a.theme, &"village")
	assert_eq(a.exits.size(), 1, "Eingang zu den Katakomben")
	for marker: StringName in [&"merchant", &"stash", &"exit_arrival"]:
		assert_true(a.markers.has(marker), "Marker %s" % marker)
	assert_eq(_check_reachable(a), "")


func test_minimap_image_matches_layout() -> void:
	var layout := World.generate(3, _config(1))
	var image := MinimapData.build_image(layout)
	var rect := MinimapData.cell_rect(layout)
	assert_eq(image.get_size(), rect.size)
	var start_pixel := Vector2i(MinimapData.world_to_pixel(layout, layout.player_start))
	assert_true(_close(image.get_pixelv(start_pixel), MinimapData.COLOR_FLOOR), "Start ist Boden")
	var exit_pixel := Vector2i(MinimapData.world_to_pixel(layout, layout.exits[0]))
	assert_true(_close(image.get_pixelv(exit_pixel), MinimapData.COLOR_EXIT), "Ausgang rot")
	assert_eq(MinimapData.room_at(layout, layout.player_start), 0)


## Prüft Erreichbarkeit und Grundregeln. Liefert "" oder eine Beschreibung des Fehlers.
func _check_layout(layout: LevelLayout) -> String:
	var problem := _check_reachable(layout)
	if not problem.is_empty():
		return problem
	var walkable := DungeonGenerator.walkable_cells(layout)
	for i in layout.rooms.size():
		var rect := layout.rooms[i]
		var found := false
		for z in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				found = found or walkable.has(Vector2i(x, z))
		if not found:
			return "Raum %d ohne Boden" % i
	if not layout.bounds.has_point(layout.player_start + Vector3(0, 0.1, 0)):
		return "Start außerhalb der Grenzen"
	if layout.depth < World.BOSS_DEPTH and layout.exits.is_empty():
		return "kein Ausgang"
	return ""


## Flutfüllung vom Start: Alle begehbaren Zellen, Ausgänge und Spawnpunkte müssen erreichbar sein.
func _check_reachable(layout: LevelLayout) -> String:
	var walkable := DungeonGenerator.walkable_cells(layout)
	var start := WorldTiles.world_to_cell(layout.player_start, layout.cell_size)
	if not walkable.has(start):
		return "Start nicht begehbar"
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for dir in WorldTiles.DIRECTIONS:
			var next: Vector2i = cell + dir
			if walkable.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	if seen.size() != walkable.size():
		return (
			"%d von %d Zellen nicht erreichbar" % [walkable.size() - seen.size(), walkable.size()]
		)
	var points: Array[Vector3] = []
	points.append_array(layout.exits)
	points.append_array(layout.spawn_points)
	points.append_array(layout.markers.values())
	if layout.entrance != Vector3.INF:
		points.append(layout.entrance)
	for point in points:
		if not seen.has(WorldTiles.world_to_cell(point, layout.cell_size)):
			return "Punkt %s nicht erreichbar" % point
	return ""


## Farben aus einem RGBA8-Bild sind auf 1/255 gerundet.
func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01
