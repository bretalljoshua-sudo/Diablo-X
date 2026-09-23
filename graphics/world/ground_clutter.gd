class_name GroundClutter
extends Node3D
## Kleinkram am Boden einer Ebene (AP1): Grasbüschel und Kiesel im Dorf, Kiesel, Schutt an den
## Wänden, Knochen, Flecken und Risse in Katakomben und Bossraum. Nur Optik, ohne Kollision und
## ohne Einfluss auf die Navigation. Alles über MultiMesh (ein Draw Call je Art) und Decals.
## Menge nach QualityPreset.clutter_density. Graphics baut das bei level_loaded.

const GRASS_SHADER := preload("res://graphics/shaders/grass_blades.gdshader")
const STAIN_TEXTURE := preload("res://graphics/textures/decal_stain.png")
const CRACK_TEXTURE := preload("res://graphics/textures/decal_crack.png")

## Büschel je Graszelle, Kiesel je Bodenzelle, Schuttbrocken je Wandseite, Knochen je Zelle,
## Decals je Zelle (bei clutter_density 1).
const GRASS_PER_CELL := 70
const PEBBLES_PER_CELL := 9.0
const RUBBLE_PER_EDGE := 5.0
const BONES_PER_CELL := 0.12
const DECALS_PER_CELL := 0.35
const MAX_DECALS := 90

const FLOOR_IDS: Array[int] = [
	WorldTiles.Id.FLOOR,
	WorldTiles.Id.FLOOR_CRACKED,
	WorldTiles.Id.FLOOR_RUBBLE,
	WorldTiles.Id.FLOOR_BOSS
]
const VILLAGE_GROUND_IDS: Array[int] = [WorldTiles.Id.GROUND_PATH, WorldTiles.Id.GROUND_DIRT]

var grass: MultiMeshInstance3D
var pebbles: MultiMeshInstance3D
var rubble: MultiMeshInstance3D
var bones: MultiMeshInstance3D
var decals: Array[Decal] = []

var _rng := RandomNumberGenerator.new()
var _layout: LevelLayout
var _density: float = 1.0


## Baut den Kleinkram für layout. density: Faktor aus der Grafikstufe (0 = nichts).
static func build(layout: LevelLayout, density: float) -> GroundClutter:
	var clutter := GroundClutter.new()
	clutter.name = "AP1GroundClutter"
	clutter._layout = layout
	clutter._density = maxf(density, 0.0)
	clutter._rng.seed = hash([layout.seed, layout.depth, "clutter"])
	if density > 0.0:
		clutter._build()
	return clutter


## Anzahl aller Exemplare (für Tests und die Leistungsanzeige).
func instance_count() -> int:
	var total := decals.size()
	for multi: MultiMeshInstance3D in [grass, pebbles, rubble, bones]:
		if multi != null:
			total += multi.multimesh.instance_count
	return total


func _build() -> void:
	var grass_cells: Array[Vector2i] = []
	var floor_cells: Array[Vector2i] = []
	for cell in _layout.cells:
		if cell.y != 0:
			continue
		var id: int = _layout.cells[cell]
		var flat := Vector2i(cell.x, cell.z)
		if WorldTiles.is_blocking_prop(_layout.props.get(cell, -1)):
			continue
		if id == WorldTiles.Id.GROUND_GRASS:
			grass_cells.append(flat)
		elif FLOOR_IDS.has(id) or VILLAGE_GROUND_IDS.has(id):
			floor_cells.append(flat)
	grass_cells.sort()
	floor_cells.sort()
	var village := _layout.theme == &"village"
	if not grass_cells.is_empty():
		grass = _build_grass(grass_cells)
	var pebble_color := Color(0.4, 0.37, 0.33) if village else Color(0.34, 0.34, 0.36)
	pebbles = _build_pebbles(floor_cells, pebble_color)
	if not village:
		rubble = _build_rubble(floor_cells)
		bones = _build_bones(floor_cells)
		_build_decals(floor_cells)
	for node: Node3D in [grass, pebbles, rubble, bones]:
		if node != null:
			add_child(node)


func _cell_center(cell: Vector2i) -> Vector3:
	return WorldTiles.cell_center(cell, _layout.cell_size)


func _random_in_cell(cell: Vector2i, margin: float = 0.1) -> Vector3:
	var half := _layout.cell_size * 0.5 - Vector3.ONE * margin
	return (
		_cell_center(cell)
		+ Vector3(_rng.randf_range(-half.x, half.x), 0.0, _rng.randf_range(-half.z, half.z))
	)


func _count(per_cell: float, cells: int) -> int:
	return int(round(per_cell * cells * _density))


func _multimesh(mesh: Mesh, count: int, colors: bool) -> MultiMesh:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = colors
	multi.mesh = mesh
	multi.instance_count = count
	return multi


func _instance(multi: MultiMesh, node_name: String) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multi
	return node


# --- Gras ---


func _build_grass(cells: Array[Vector2i]) -> MultiMeshInstance3D:
	var count := _count(GRASS_PER_CELL, cells.size())
	var multi := _multimesh(grass_clump_mesh(), count, true)
	# Großflächige Flecken: trockenere, gelbliche Stellen und sattere, höhere Wiese.
	var patches := FastNoiseLite.new()
	patches.seed = _layout.seed
	patches.frequency = 0.07
	for i in count:
		var cell := cells[_rng.randi_range(0, cells.size() - 1)]
		var position := _random_in_cell(cell, 0.0)
		var patch := patches.get_noise_2d(position.x, position.z) * 0.5 + 0.5
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(
			Vector3.ONE * _rng.randf_range(0.7, 1.2) * lerpf(0.8, 1.25, 1.0 - patch)
		)
		multi.set_instance_transform(i, Transform3D(basis, position))
		var shade := _rng.randf_range(0.8, 1.15)
		var dry := clampf(patch * 1.4 - 0.35 + _rng.randf_range(-0.15, 0.15), 0.0, 1.0)
		multi.set_instance_color(
			i,
			Color(shade * (1.0 + dry * 0.6), shade * (1.0 + dry * 0.2), shade * (0.9 - dry * 0.2))
		)
	var node := _instance(multi, "Grass")
	var material := ShaderMaterial.new()
	material.shader = GRASS_SHADER
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 60.0
	return node


## Ein Büschel aus neun gebogenen Halmen (je drei Dreiecke). UV.y = Höhe im Halm.
static func grass_clump_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 9:
		var angle := rng.randf() * TAU
		var root := Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.0, 0.22)
		var facing := rng.randf() * TAU
		var side := Vector3(cos(facing), 0.0, sin(facing))
		var lean := Vector3(-side.z, 0.0, side.x) * rng.randf_range(0.05, 0.22)
		var height := rng.randf_range(0.28, 0.62)
		var width := rng.randf_range(0.025, 0.045)
		var mid := root + Vector3(0, height * 0.55, 0) + lean * 0.35
		var tip := root + Vector3(0, height, 0) + lean
		var normal := Vector3(-side.z, 0.4, side.x).normalized()
		var points := [
			[root - side * width, 0.0],
			[root + side * width, 0.0],
			[mid - side * width * 0.65, 0.55],
			[mid + side * width * 0.65, 0.55],
			[tip, 1.0],
		]
		for tri: Array in [[0, 1, 2], [1, 3, 2], [2, 3, 4]]:
			for index: int in tri:
				var point: Array = points[index]
				st.set_normal(normal)
				st.set_uv(Vector2(0.5, point[1]))
				st.add_vertex(point[0])
	return st.commit()


# --- Kiesel, Schutt, Knochen ---


func _build_pebbles(cells: Array[Vector2i], tint: Color) -> MultiMeshInstance3D:
	var count := _count(PEBBLES_PER_CELL, cells.size())
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 0.7
	mesh.radial_segments = 7
	mesh.rings = 3
	var multi := _multimesh(mesh, count, false)
	for i in count:
		var cell := cells[_rng.randi_range(0, cells.size() - 1)]
		var size := _rng.randf_range(0.05, 0.16) * (2.0 if _rng.randf() < 0.08 else 1.0)
		var scale := Vector3(
			size * _rng.randf_range(0.8, 1.4),
			size * _rng.randf_range(0.35, 0.6),
			size * _rng.randf_range(0.8, 1.2)
		)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(scale)
		var at := _random_in_cell(cell)
		at.y = scale.y * 0.1
		multi.set_instance_transform(i, Transform3D(basis, at))
	var node := _instance(multi, "Pebbles")
	node.material_override = MaterialLibrary.get_material(&"cobble", tint)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 45.0
	return node


## Schuttbrocken an Bodenzellen, die an eine Wand (nicht begehbare Zelle) grenzen.
func _build_rubble(cells: Array[Vector2i]) -> MultiMeshInstance3D:
	var walkable: Dictionary[Vector2i, bool] = {}
	for cell in cells:
		walkable[cell] = true
	var edges: Array[Array] = []
	for cell in cells:
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not walkable.has(cell + dir):
				edges.append([cell, dir])
	var count := _count(RUBBLE_PER_EDGE, edges.size())
	var mesh := BoxMesh.new()
	var multi := _multimesh(mesh, count, false)
	var half := _layout.cell_size.x * 0.5
	for i in count:
		var edge: Array = edges[_rng.randi_range(0, edges.size() - 1)]
		var cell: Vector2i = edge[0]
		var dir: Vector2i = edge[1]
		var along := Vector3(dir.y, 0, dir.x) * _rng.randf_range(-half, half)
		var toward := Vector3(dir.x, 0, dir.y) * (half - _rng.randf_range(0.15, 0.9))
		var at := _cell_center(cell) + along + toward
		var size := _rng.randf_range(0.1, 0.38)
		var scale := Vector3(
			size * _rng.randf_range(0.7, 1.5),
			size * _rng.randf_range(0.4, 0.9),
			size * _rng.randf_range(0.7, 1.3)
		)
		var basis := (
			Basis
			. from_euler(
				Vector3(
					_rng.randf_range(-0.4, 0.4), _rng.randf() * TAU, _rng.randf_range(-0.4, 0.4)
				)
			)
			. scaled(scale)
		)
		at.y = scale.y * 0.25
		multi.set_instance_transform(i, Transform3D(basis, at))
	var node := _instance(multi, "Rubble")
	node.material_override = MaterialLibrary.get_material(&"cobble", Color(0.3, 0.3, 0.32))
	node.visibility_range_end = 50.0
	return node


## Knochenhaufen aus dem Baukasten (prop_bones), verstreut und gedreht.
func _build_bones(cells: Array[Vector2i]) -> MultiMeshInstance3D:
	var library := WorldKit.get_library()
	var item := WorldKit.item_for(WorldTiles.Id.PROP_BONES)
	if library == null or item == GridMap.INVALID_CELL_ITEM:
		return null
	var mesh := library.get_item_mesh(item)
	if mesh == null:
		return null
	var per_cell := BONES_PER_CELL * (2.5 if _layout.theme == &"boss" else 1.0)
	var count := _count(per_cell, cells.size())
	var multi := _multimesh(mesh, count, false)
	for i in count:
		var cell := cells[_rng.randi_range(0, cells.size() - 1)]
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(
			Vector3.ONE * _rng.randf_range(0.55, 0.9)
		)
		multi.set_instance_transform(i, Transform3D(basis, _random_in_cell(cell, 0.4)))
	var node := _instance(multi, "Bones")
	node.visibility_range_end = 50.0
	return node


# --- Flecken und Risse ---


func _build_decals(cells: Array[Vector2i]) -> void:
	var count := mini(_count(DECALS_PER_CELL, cells.size()), MAX_DECALS)
	var boss := _layout.theme == &"boss"
	for i in count:
		var cell := cells[_rng.randi_range(0, cells.size() - 1)]
		var decal := Decal.new()
		decal.name = "Decal%d" % i
		var crack := _rng.randf() < 0.45
		decal.texture_albedo = CRACK_TEXTURE if crack else STAIN_TEXTURE
		var size := _rng.randf_range(1.6, 3.4) if crack else _rng.randf_range(1.2, 3.0)
		decal.size = Vector3(size, 0.6, size)
		if crack:
			decal.modulate = Color(0.05, 0.05, 0.06, 0.85)
		elif boss and _rng.randf() < 0.6:
			decal.modulate = Color(0.16, 0.02, 0.015, 0.7)
		else:
			decal.modulate = Color(0.06, 0.055, 0.05, _rng.randf_range(0.35, 0.6))
		decal.albedo_mix = 1.0
		decal.upper_fade = 0.2
		decal.lower_fade = 0.2
		decal.cull_mask = 1
		decal.distance_fade_enabled = true
		decal.distance_fade_begin = 40.0
		decal.distance_fade_length = 10.0
		decal.position = _random_in_cell(cell, 0.3)
		decal.rotation.y = _rng.randf() * TAU
		add_child(decal)
		decals.append(decal)
