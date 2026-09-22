class_name PlaceholderKit
extends RefCounted
## Baut eine MeshLibrary aus grauen Blöcken für alle Zellnamen aus WorldTiles.
## Platzhalter, bis AP8 die echte Bibliothek unter WorldKit.REAL_PATH liefert.
## Maße und Ausrichtung folgen der Absprache in docs/pakete/AP6.md.

const WALL_HEIGHT := 2.5
const HOUSE_HEIGHT := 4.0

static var _cache: MeshLibrary
static var _materials: Dictionary[Color, StandardMaterial3D] = {}


static func get_library() -> MeshLibrary:
	if _cache == null:
		_cache = build()
	return _cache


static func build() -> MeshLibrary:
	var library := MeshLibrary.new()
	for id: int in WorldTiles.NAMES:
		library.create_item(id)
		library.set_item_name(id, WorldTiles.NAMES[id])
		var parts := _parts_for(id)
		library.set_item_mesh(id, _compose(parts[0]))
		library.set_item_shapes(id, parts[1])
	return library


## Liefert [Mesh-Teile, Kollisionsformen] für ein Item.
## Mesh-Teil: [PrimitiveMesh, Position, Farbe, leuchtet]. Formen: [Shape3D, Transform3D, …].
static func _parts_for(id: int) -> Array:
	var stone := Color(0.34, 0.33, 0.32)
	var floor_color := Color(0.24, 0.23, 0.22)
	var dark := Color(0.12, 0.11, 0.11)
	var wood := Color(0.36, 0.24, 0.14)
	var fire := Color(1.0, 0.55, 0.2)
	var floor_part := [_box(Vector3(4, 0.2, 4)), Vector3(0, -0.1, 0), floor_color, false]
	var floor_shape := [BoxShape3D.new(), Transform3D(Basis(), Vector3(0, -0.1, 0))]
	(floor_shape[0] as BoxShape3D).size = Vector3(4, 0.2, 4)
	var meshes: Array = []
	var shapes: Array = []
	match id:
		WorldTiles.Id.FLOOR:
			meshes = [floor_part]
		WorldTiles.Id.FLOOR_CRACKED:
			meshes = [[floor_part[0], floor_part[1], Color(0.21, 0.2, 0.19), false]]
		WorldTiles.Id.FLOOR_RUBBLE:
			meshes = [
				floor_part, [_box(Vector3(0.8, 0.3, 0.6)), Vector3(1, 0.15, -0.8), stone, false]
			]
		WorldTiles.Id.FLOOR_BOSS:
			meshes = [[floor_part[0], floor_part[1], Color(0.25, 0.12, 0.12), false]]
		WorldTiles.Id.PORTAL:
			meshes = [
				floor_part, [_cylinder(1.4, 0.2), Vector3(0, 0.1, 0), Color(0.3, 0.45, 1.0), true]
			]
		WorldTiles.Id.WALL, WorldTiles.Id.WALL_DOUBLE, WorldTiles.Id.WALL_END:
			meshes = [_block(stone, WALL_HEIGHT)]
			shapes = _block_shape(WALL_HEIGHT)
			# Helle Kante auf der begehbaren Seite (+Z), damit man Drehfehler sieht.
			meshes.append(
				[_box(Vector3(4, 0.3, 0.1)), Vector3(0, WALL_HEIGHT, 1.95), stone * 1.4, false]
			)
		WorldTiles.Id.WALL_CORNER, WorldTiles.Id.WALL_CORNER_OUTER:
			meshes = [_block(stone * 0.9, WALL_HEIGHT)]
			shapes = _block_shape(WALL_HEIGHT)
		WorldTiles.Id.DOORWAY:
			meshes = [
				floor_part,
				[_box(Vector3(0.6, 3.0, 0.8)), Vector3(-1.7, 1.5, 0), stone, false],
				[_box(Vector3(0.6, 3.0, 0.8)), Vector3(1.7, 1.5, 0), stone, false],
				[_box(Vector3(4.0, 0.5, 0.8)), Vector3(0, 3.1, 0), stone, false],
			]
			shapes = _box_shape(Vector3(0.6, 3, 0.8), Vector3(-1.7, 1.5, 0))
			shapes.append_array(_box_shape(Vector3(0.6, 3, 0.8), Vector3(1.7, 1.5, 0)))
		WorldTiles.Id.PILLAR:
			meshes = [floor_part, [_box(Vector3(1.4, 3.2, 1.4)), Vector3(0, 1.6, 0), stone, false]]
			shapes = _box_shape(Vector3(1.4, 3.2, 1.4), Vector3(0, 1.6, 0))
		WorldTiles.Id.STAIRS_DOWN:
			meshes = [floor_part]
			for step in 4:
				meshes.append(
					[
						_box(Vector3(3.2, 0.1, 0.7)),
						Vector3(0, 0.01 - step * 0.02, 0.6 - step * 0.7),
						dark.lerp(Color.BLACK, step * 0.25),
						false
					]
				)
		WorldTiles.Id.STAIRS_UP:
			meshes = [floor_part]
			for step in 4:
				meshes.append(
					[
						_box(Vector3(3.2, 0.2 * (step + 1), 0.7)),
						Vector3(0, 0.1 * (step + 1), 0.6 - step * 0.7),
						stone * 1.1,
						false
					]
				)
		WorldTiles.Id.PROP_BARREL:
			meshes = [[_cylinder(0.5, 1.1), Vector3(0, 0.55, 0), wood, false]]
			shapes = _box_shape(Vector3(1, 1.1, 1), Vector3(0, 0.55, 0))
		WorldTiles.Id.PROP_CRATE:
			meshes = [[_box(Vector3(1.1, 1.1, 1.1)), Vector3(0, 0.55, 0), wood * 1.2, false]]
			shapes = _box_shape(Vector3(1.1, 1.1, 1.1), Vector3(0, 0.55, 0))
		WorldTiles.Id.PROP_BONES:
			meshes = [
				[
					_box(Vector3(1.2, 0.15, 0.9)),
					Vector3(0.3, 0.08, 0.2),
					Color(0.8, 0.78, 0.7),
					false
				]
			]
		WorldTiles.Id.PROP_CANDLES:
			meshes = [[_cylinder(0.1, 0.4), Vector3(-0.5, 0.2, 0.4), fire, true]]
		WorldTiles.Id.PROP_COFFIN:
			meshes = [[_box(Vector3(1.1, 0.9, 2.3)), Vector3(0, 0.45, 0), stone * 1.2, false]]
			shapes = _box_shape(Vector3(1.1, 0.9, 2.3), Vector3(0, 0.45, 0))
		WorldTiles.Id.PROP_RUBBLE:
			meshes = [[_box(Vector3(1.6, 0.7, 1.4)), Vector3(0, 0.35, 0), stone * 0.8, false]]
			shapes = _box_shape(Vector3(1.6, 0.7, 1.4), Vector3(0, 0.35, 0))
		WorldTiles.Id.PROP_TABLE:
			meshes = [[_box(Vector3(2.0, 0.9, 1.1)), Vector3(0, 0.45, 0), wood, false]]
			shapes = _box_shape(Vector3(2.0, 0.9, 1.1), Vector3(0, 0.45, 0))
		WorldTiles.Id.PROP_BANNER:
			meshes = [
				[
					_box(Vector3(1.0, 2.0, 0.05)),
					Vector3(0, 1.8, -1.9),
					Color(0.4, 0.05, 0.05),
					false
				]
			]
		WorldTiles.Id.TORCH_WALL:
			meshes = [[_box(Vector3(0.2, 0.5, 0.2)), Vector3(0, 2.4, -1.85), fire, true]]
		WorldTiles.Id.BRAZIER:
			meshes = [
				[_cylinder(0.25, 1.0), Vector3(0, 0.5, 0), dark, false],
				[_cylinder(0.6, 0.3), Vector3(0, 1.1, 0), fire, true],
			]
			shapes = _box_shape(Vector3(1.2, 1.2, 1.2), Vector3(0, 0.6, 0))
		WorldTiles.Id.PROP_CHEST:
			meshes = [[_box(Vector3(1.2, 0.8, 0.8)), Vector3(0, 0.4, 0), wood * 1.3, false]]
			shapes = _box_shape(Vector3(1.2, 0.8, 0.8), Vector3(0, 0.4, 0))
		WorldTiles.Id.PROP_COBWEB:
			meshes = [
				[
					_box(Vector3(1.2, 1.2, 0.02)),
					Vector3(-1.4, 2.0, -1.9),
					Color(0.7, 0.7, 0.7),
					false
				]
			]
		WorldTiles.Id.GROUND_GRASS:
			meshes = [[floor_part[0], floor_part[1], Color(0.16, 0.24, 0.12), false]]
		WorldTiles.Id.GROUND_PATH:
			meshes = [[floor_part[0], floor_part[1], Color(0.33, 0.3, 0.26), false]]
		WorldTiles.Id.GROUND_DIRT:
			meshes = [[floor_part[0], floor_part[1], Color(0.25, 0.19, 0.13), false]]
		WorldTiles.Id.HOUSE_WALL, WorldTiles.Id.HOUSE_CORNER:
			meshes = [_block(Color(0.55, 0.5, 0.42), HOUSE_HEIGHT)]
			shapes = _block_shape(HOUSE_HEIGHT)
		WorldTiles.Id.HOUSE_DOOR:
			meshes = [
				_block(Color(0.55, 0.5, 0.42), HOUSE_HEIGHT),
				[_box(Vector3(1.4, 2.4, 0.1)), Vector3(0, 1.2, 2.0), wood * 0.7, false],
			]
			shapes = _block_shape(HOUSE_HEIGHT)
		WorldTiles.Id.HOUSE_ROOF:
			meshes = [_block(Color(0.35, 0.16, 0.12), HOUSE_HEIGHT + 1.0)]
			shapes = _block_shape(HOUSE_HEIGHT)
		WorldTiles.Id.FENCE:
			meshes = [[_box(Vector3(4.0, 1.0, 0.15)), Vector3(0, 0.5, 0), wood, false]]
			shapes = _box_shape(Vector3(4.0, 1.0, 0.3), Vector3(0, 0.5, 0))
		WorldTiles.Id.TREE:
			meshes = [
				[_cylinder(0.3, 2.5), Vector3(0, 1.25, 0), wood * 0.8, false],
				[_sphere(1.6), Vector3(0, 3.4, 0), Color(0.12, 0.22, 0.1), false],
			]
			shapes = _box_shape(Vector3(0.8, 2.5, 0.8), Vector3(0, 1.25, 0))
		WorldTiles.Id.ROCK:
			meshes = [_block(Color(0.3, 0.3, 0.3), 3.0)]
			shapes = _block_shape(3.0)
		WorldTiles.Id.WELL:
			meshes = [[_cylinder(1.0, 0.9), Vector3(0, 0.45, 0), stone, false]]
			shapes = _box_shape(Vector3(2.0, 0.9, 2.0), Vector3(0, 0.45, 0))
		WorldTiles.Id.LAMP_POST:
			meshes = [
				[_box(Vector3(0.2, 3.0, 0.2)), Vector3(0, 1.5, 0), dark, false],
				[_box(Vector3(0.4, 0.4, 0.4)), Vector3(0, 3.1, 0), fire, true],
			]
			shapes = _box_shape(Vector3(0.4, 3.0, 0.4), Vector3(0, 1.5, 0))
		WorldTiles.Id.MARKET_STALL:
			meshes = [
				[_box(Vector3(3.0, 1.0, 1.4)), Vector3(0, 0.5, 0), wood, false],
				[_box(Vector3(3.4, 0.1, 2.0)), Vector3(0, 2.4, -0.2), Color(0.5, 0.15, 0.1), false],
			]
			shapes = _box_shape(Vector3(3.0, 1.0, 1.4), Vector3(0, 0.5, 0))
		WorldTiles.Id.CRYPT_ENTRANCE:
			meshes = [
				[floor_part[0], floor_part[1], dark, false],
				[_box(Vector3(0.6, 3.5, 0.8)), Vector3(-1.7, 1.75, -1.0), stone, false],
				[_box(Vector3(0.6, 3.5, 0.8)), Vector3(1.7, 1.75, -1.0), stone, false],
				[_box(Vector3(4.0, 0.6, 0.8)), Vector3(0, 3.7, -1.0), stone, false],
			]
	if id in WorldTiles.WALKABLE_CELLS:
		shapes.append_array(floor_shape)
	return [meshes, shapes]


static func _block(color: Color, height: float) -> Array:
	return [_box(Vector3(4, height, 4)), Vector3(0, height * 0.5, 0), color, false]


static func _block_shape(height: float) -> Array:
	return _box_shape(Vector3(4, height, 4), Vector3(0, height * 0.5, 0))


static func _box_shape(size: Vector3, position: Vector3) -> Array:
	var shape := BoxShape3D.new()
	shape.size = size
	return [shape, Transform3D(Basis(), position)]


static func _box(size: Vector3) -> PrimitiveMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _cylinder(radius: float, height: float) -> PrimitiveMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return mesh


static func _sphere(radius: float) -> PrimitiveMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh


## Setzt die Teile zu einem ArrayMesh zusammen, eine Oberfläche pro Teil.
static func _compose(parts: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for part: Array in parts:
		var tool := SurfaceTool.new()
		tool.append_from(part[0], 0, Transform3D(Basis(), part[1]))
		tool.set_material(_material(part[2], part[3]))
		tool.commit(mesh)
	return mesh


static func _material(color: Color, glowing: bool) -> StandardMaterial3D:
	var key := Color(color.r, color.g, color.b, 0.5 if glowing else 1.0)
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color.r, color.g, color.b)
		material.roughness = 0.9
		if glowing:
			material.emission_enabled = true
			material.emission = Color(color.r, color.g, color.b)
			material.emission_energy_multiplier = 2.0
		_materials[key] = material
	return _materials[key]
