extends GutTest
## AP8: Baukasten-Bibliothek für AP6 und Requisiten-Szenen.

const KIT_PATH := "res://assets/world/world_kit.tres"
const PROP_DIR := "res://assets/props/"
## Teile, durch die man nicht hindurchlaufen darf (Wände und Säule).
const SOLID_CELLS: Array[int] = [
	WorldTiles.Id.WALL,
	WorldTiles.Id.WALL_CORNER,
	WorldTiles.Id.WALL_CORNER_OUTER,
	WorldTiles.Id.WALL_DOUBLE,
	WorldTiles.Id.WALL_END,
	WorldTiles.Id.PILLAR,
	WorldTiles.Id.HOUSE_WALL,
	WorldTiles.Id.HOUSE_CORNER,
]


func _kit() -> MeshLibrary:
	return load(KIT_PATH) as MeshLibrary


func test_kit_is_a_mesh_library() -> void:
	assert_not_null(_kit(), "world_kit.tres ist eine MeshLibrary")


func test_every_ap6_name_exists_with_mesh() -> void:
	var kit := _kit()
	for id: int in WorldTiles.NAMES:
		var tile_name := WorldTiles.NAMES[id]
		var item := kit.find_item_by_name(tile_name)
		assert_gt(item, -1, "Item %s vorhanden" % tile_name)
		if item < 0:
			continue
		assert_eq(item, id, "%s hat dieselbe ID wie in WorldTiles" % tile_name)
		var mesh := kit.get_item_mesh(item)
		assert_not_null(mesh, "%s hat ein Mesh" % tile_name)
		if mesh:
			assert_gt(mesh.get_surface_count(), 0, "%s hat Flächen" % tile_name)


func test_world_uses_real_kit() -> void:
	assert_true(WorldKit.uses_real_kit(), "AP6 lädt den echten Baukasten statt des Platzhalters")


func test_solid_parts_and_blocking_props_have_collision() -> void:
	var kit := _kit()
	var ids: Array[int] = []
	ids.append_array(SOLID_CELLS)
	ids.append_array(WorldTiles.BLOCKING_PROPS)
	for id in ids:
		var tile_name := WorldTiles.NAMES[id]
		var shapes := kit.get_item_shapes(kit.find_item_by_name(tile_name))
		assert_gt(shapes.size(), 0, "%s hat eine Kollision" % tile_name)


func test_meshes_fit_in_cell() -> void:
	# Teile dürfen seitlich höchstens wenig über die 4-m-Zelle hinausragen, sonst überlappen Nachbarn.
	var kit := _kit()
	for id: int in WorldTiles.NAMES:
		var mesh := kit.get_item_mesh(id)
		if mesh == null:
			continue
		var box := mesh.get_aabb()
		var tile_name := WorldTiles.NAMES[id]
		assert_gt(box.position.x, -2.6, "%s links" % tile_name)
		assert_lt(box.end.x, 2.6, "%s rechts" % tile_name)
		assert_gt(box.position.z, -2.6, "%s hinten" % tile_name)
		assert_lt(box.end.z, 2.6, "%s vorn" % tile_name)


func test_prop_scenes_load() -> void:
	var dir := DirAccess.open(PROP_DIR)
	assert_not_null(dir)
	var count := 0
	for file in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		var scene := load(PROP_DIR + file) as PackedScene
		assert_not_null(scene, "%s lädt" % file)
		var prop := scene.instantiate()
		assert_true(prop is StaticBody3D, "%s ist ein StaticBody3D" % file)
		var meshes := prop.find_children("*", "MeshInstance3D", false)
		assert_gt(meshes.size(), 0, "%s hat ein Mesh" % file)
		prop.free()
		count += 1
	assert_gt(count, 20, "Requisiten-Szenen vorhanden")
