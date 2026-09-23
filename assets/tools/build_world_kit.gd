extends SceneTree
## Baut den Baukasten für Dungeon und Dorf als MeshLibrary (AP8) und die Requisiten-Szenen.
##
## Aufruf (nach einem Import):
##   godot --headless --path . -s res://assets/tools/build_world_kit.gd
##
## Erzeugt:
##   assets/world/world_kit.tres        MeshLibrary, Namen und Ausrichtung laut AP6.md
##   assets/world/meshes/<name>.res     zusammengesetztes Mesh je Item (ein Material je Fläche)
##   assets/props/<name>.tscn           Requisiten als eigene Szenen (Mesh und Kollision)
##
## Regeln aus AP6: Zelle 4 × 4 × 4 m, Ursprung in der Zellmitte auf Bodenhöhe (y = 0),
## Blickrichtung lokal +Z, Wandstück an der +Z-Kante, Kollision steckt im Item.

const KIT_PATH := "res://assets/world/world_kit.tres"
const MESH_DIR := "res://assets/world/meshes/"
const PROP_DIR := "res://assets/props/"
const DUNGEON := "res://assets/world/kaykit_dungeon/"
const HALLOWEEN := "res://assets/world/kaykit_halloween/"
const MEDIEVAL := "res://assets/world/kaykit_medieval/"
const GRASS_MATERIAL := "res://assets/world/materials/grass.tres"
const COBWEB_MATERIAL := "res://assets/world/materials/cobweb.tres"

const CELL := 4.0
const WALL_Z := 1.5
## Items, die zusätzlich als Requisiten-Szene unter assets/props/ gespeichert werden.
const PROP_SCENES: Array[String] = [
	"prop_barrel",
	"prop_crate",
	"prop_bones",
	"prop_candles",
	"prop_coffin",
	"prop_rubble",
	"prop_table",
	"prop_banner",
	"torch_wall",
	"brazier",
	"prop_chest",
	"prop_cobweb",
	"pillar",
	"doorway",
	"stairs_down",
	"stairs_up",
	"portal",
	"fence",
	"tree",
	"rock",
	"well",
	"lamp_post",
	"market_stall",
	"crypt_entrance",
]

var _scene_cache: Dictionary[String, Node3D] = {}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MESH_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROP_DIR))
	var library := MeshLibrary.new()
	var ok := true
	for item: Array in _items():
		ok = _add_item(library, item[0], item[1], item[2], item[3]) and ok
	ok = _save(library, KIT_PATH) and ok
	for node: Node3D in _scene_cache.values():
		node.free()
	print(
		(
			"build_world_kit: %s (%d Items)"
			% ["fertig" if ok else "FEHLER", library.get_item_list().size()]
		)
	)
	quit(0 if ok else 1)


## [ID, Name, Teile, Kollision]. Teile: [Pfad, Transform3D, auszulassende Knoten].
## Kollision: [Größe, Mittelpunkt] als Quader. IDs und Namen wie in docs/pakete/AP6.md.
func _items() -> Array:
	var floor_box := [[Vector3(CELL, 0.2, CELL), Vector3(0, -0.1, 0)]]
	var solid_cell := [[Vector3(CELL, CELL, CELL), Vector3(0, CELL / 2.0, 0)]]
	var wall_box := [Vector3(CELL, CELL, 1.0), Vector3(0, 2, WALL_Z)]
	var roof := _p(DUNGEON + "floor_wood_large_dark.glb", _t(Vector3(0, CELL, 0)))
	var floor := _p(DUNGEON + "floor_tile_large.glb")
	return [
		# Katakomben, Aufbau
		[0, "floor", [floor], floor_box],
		[
			1,
			"floor_cracked",
			[
				_p(DUNGEON + "floor_tile_small_broken_a.glb", _t(Vector3(-1, 0, -1))),
				_p(DUNGEON + "floor_tile_small.glb", _t(Vector3(1, 0, -1))),
				_p(DUNGEON + "floor_tile_small.glb", _t(Vector3(-1, 0, 1), 90)),
				_p(DUNGEON + "floor_tile_small_broken_b.glb", _t(Vector3(1, 0, 1))),
			],
			floor_box
		],
		[2, "floor_rubble", [_p(DUNGEON + "floor_dirt_large_rocky.glb")], floor_box],
		[3, "wall", [_p(DUNGEON + "wall.glb", _t(Vector3(0, 0, WALL_Z)))], [wall_box]],
		[
			4,
			"wall_corner",
			[_p(DUNGEON + "wall_endcap.glb", _t(Vector3(1, 0, WALL_Z)))],
			[[Vector3(1, CELL, 1), Vector3(WALL_Z, 2, WALL_Z)]]
		],
		[
			5,
			"wall_corner_outer",
			[
				_p(DUNGEON + "wall.glb", _t(Vector3(0, 0, WALL_Z))),
				_p(DUNGEON + "wall.glb", _t(Vector3(WALL_Z, 0, 0), 90)),
			],
			[wall_box, [Vector3(1, CELL, CELL), Vector3(WALL_Z, 2, 0)]]
		],
		[
			6,
			"wall_double",
			[_p(DUNGEON + "wall.glb", _t(Vector3.ZERO, 0, Vector3(1, 1, 3)))],
			[[Vector3(CELL, CELL, 3), Vector3(0, 2, 0)]]
		],
		[
			7,
			"wall_end",
			[_p(DUNGEON + "wall.glb", _t(Vector3(0, 0, -0.25), 90, Vector3(0.875, 1, 3)))],
			[[Vector3(3, CELL, 3.5), Vector3(0, 2, -0.25)]]
		],
		[
			8,
			"doorway",
			[floor, _p(DUNGEON + "wall_doorway.glb", Transform3D(), ["wall_doorway_door"])],
			(
				floor_box
				+ [
					[Vector3(0.8, CELL, 1), Vector3(-1.6, 2, 0)],
					[Vector3(0.8, CELL, 1), Vector3(1.6, 2, 0)],
				]
			)
		],
		[
			9,
			"pillar",
			[floor, _p(DUNGEON + "pillar.glb")],
			floor_box + [[Vector3(1.5, CELL, 1.5), Vector3(0, 2, 0)]]
		],
		[
			10,
			"stairs_down",
			[_p(DUNGEON + "stairs.glb", _t(Vector3(0, -4.1, 2), 180, Vector3(0.8, 0.8, 1)))],
			floor_box
		],
		[
			11,
			"stairs_up",
			[floor, _p(DUNGEON + "stairs.glb", _t(Vector3(0, 0, -2), 0, Vector3(0.8, 0.8, 1)))],
			floor_box
		],
		[12, "floor_boss", [_p(DUNGEON + "floor_tile_big_grate.glb")], floor_box],
		[
			13,
			"portal",
			[
				floor,
				_p(
					DUNGEON + "floor_foundation_allsides.glb",
					_t(Vector3.ZERO, 0, Vector3(1.4, 0.1, 1.4))
				),
			],
			floor_box
		],
		# Requisiten
		[
			20,
			"prop_barrel",
			[
				_p(DUNGEON + "barrel_large.glb", _t(Vector3(-0.6, 0, -0.4))),
				_p(DUNGEON + "barrel_small.glb", _t(Vector3(0.9, 0, 0.6))),
				_p(DUNGEON + "barrel_small.glb", _t(Vector3(0.7, 0, -1.2), 40)),
			],
			[
				[Vector3(1.8, 2, 1.8), Vector3(-0.6, 1, -0.4)],
				[Vector3(1, 1, 1), Vector3(0.9, 0.5, 0.6)],
				[Vector3(1, 1, 1), Vector3(0.7, 0.5, -1.2)],
			]
		],
		[
			21,
			"prop_crate",
			[_p(DUNGEON + "crates_stacked.glb")],
			[[Vector3(2.1, 2.1, 2.2), Vector3(0, 1.05, 0)]]
		],
		[
			22,
			"prop_bones",
			[
				_p(HALLOWEEN + "bone_a.glb", _t(Vector3(0.6, 0.1, 0.4), 30)),
				_p(HALLOWEEN + "bone_b.glb", _t(Vector3(-0.7, 0.1, -0.3), -50)),
				_p(HALLOWEEN + "skull.glb", _t(Vector3(0.1, 0, -0.8), 20, Vector3.ONE * 0.45)),
				_p(HALLOWEEN + "ribcage.glb", _t(Vector3(-0.4, 0.31, 0.8), 70, Vector3.ONE * 0.8)),
			],
			[]
		],
		[
			23,
			"prop_candles",
			[
				_p(DUNGEON + "candle_triple.glb"),
				_p(DUNGEON + "candle_lit.glb", _t(Vector3(0.7, 0, 0.5))),
				_p(DUNGEON + "candle_melted.glb", _t(Vector3(-0.6, 0, 0.3))),
			],
			[]
		],
		[
			24,
			"prop_coffin",
			[_p(HALLOWEEN + "coffin_decorated.glb")],
			[[Vector3(2, 0.9, 3), Vector3(0, 0.45, 0)]]
		],
		[
			25,
			"prop_rubble",
			[_p(DUNGEON + "rubble_large.glb", _t(Vector3.ZERO, 0, Vector3(0.5, 0.5, 0.5)))],
			[[Vector3(3.6, 1.6, 1.4), Vector3(0, 0.8, 0)]]
		],
		[
			26,
			"prop_table",
			[_p(DUNGEON + "table_medium_decorated_a.glb")],
			[[Vector3(2, 1, 2), Vector3(0, 0.5, 0)]]
		],
		[
			27,
			"prop_banner",
			[_p(DUNGEON + "banner_patterna_red.glb", _t(Vector3(0, 0, -2.38)))],
			[]
		],
		[28, "torch_wall", [_p(DUNGEON + "torch_mounted.glb", _t(Vector3(0, 2.3, -2)))], []],
		[
			29,
			"brazier",
			[
				_p(DUNGEON + "column.glb"),
				_p(DUNGEON + "torch_lit.glb", _t(Vector3(0, 2.0, 0), 0, Vector3.ONE * 1.5)),
			],
			[[Vector3(0.7, 1.4, 0.7), Vector3(0, 0.7, 0)]]
		],
		[
			30,
			"prop_chest",
			[_p(DUNGEON + "chest.glb")],
			[[Vector3(1.6, 1.1, 1.3), Vector3(0, 0.55, 0)]]
		],
		[31, "prop_cobweb", [_cobweb_piece()], []],
		# Dorf
		[40, "ground_grass", [_grass_piece()], floor_box],
		[41, "ground_path", [floor], floor_box],
		[42, "ground_dirt", [_p(DUNGEON + "floor_dirt_large.glb")], floor_box],
		[
			43,
			"house_wall",
			[_p(DUNGEON + "wall_window_closed.glb", _t(Vector3(0, 0, WALL_Z))), roof],
			solid_cell
		],
		[
			44,
			"house_corner",
			[
				_p(DUNGEON + "wall_window_closed.glb", _t(Vector3(0, 0, WALL_Z))),
				_p(DUNGEON + "wall.glb", _t(Vector3(WALL_Z, 0, 0), 90)),
				roof,
			],
			solid_cell
		],
		[
			45,
			"house_door",
			[_p(DUNGEON + "wall_doorway.glb", _t(Vector3(0, 0, WALL_Z))), roof],
			solid_cell
		],
		[
			46,
			"fence",
			[_p(HALLOWEEN + "fence.glb")],
			[[Vector3(CELL, 1.5, 0.4), Vector3(0, 0.75, 0)]]
		],
		[
			47,
			"tree",
			[_p(HALLOWEEN + "tree_dead_large.glb", _t(Vector3.ZERO, 0, Vector3.ONE * 1.2))],
			[[Vector3(0.7, 3, 0.7), Vector3(0, 1.5, 0)]]
		],
		[
			48,
			"rock",
			[_p(MEDIEVAL + "mountain_a.glb", _t(Vector3.ZERO, 0, Vector3.ONE * 2.2))],
			[[Vector3(3.6, 3, 3.6), Vector3(0, 1.5, 0)]]
		],
		[
			49,
			"well",
			[_p(MEDIEVAL + "well.glb", _t(Vector3.ZERO, 0, Vector3.ONE * 4.5))],
			[[Vector3(2.4, 1.5, 2.4), Vector3(0, 0.75, 0)]]
		],
		[
			50,
			"lamp_post",
			[_p(HALLOWEEN + "post_lantern.glb")],
			[[Vector3(0.4, 3, 0.4), Vector3(0, 1.5, 0)]]
		],
		[
			51,
			"market_stall",
			[
				_p(DUNGEON + "table_long_tablecloth_decorated_a.glb", _t(Vector3(0, 0, 0.3), 90)),
				_p(DUNGEON + "barrel_small.glb", _t(Vector3(1.4, 0, -1.1))),
				_p(DUNGEON + "keg.glb", _t(Vector3(-1.3, 0, -1.2), 30)),
			],
			[[Vector3(CELL, 1.9, 2.1), Vector3(0, 0.95, 0.3)]]
		],
		[
			52,
			"crypt_entrance",
			[_p(HALLOWEEN + "crypt.glb", _t(Vector3.ZERO, 0, Vector3.ONE * 0.5))],
			# Boden davor, sonst fällt man vor dem Übergang ins Leere (AP9).
			[[Vector3(3, CELL, 2), Vector3(0, 2, -1)], floor_box[0]]
		],
		[53, "house_roof", [roof], solid_cell],
	]


func _p(path: String, xform: Transform3D = Transform3D(), skip: Array = []) -> Array:
	return [path, xform, skip]


func _t(origin: Vector3, yaw_deg: float = 0.0, scale: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled_local(scale), origin)


func _grass_piece() -> Array:
	var plane := PlaneMesh.new()
	plane.size = Vector2(CELL, CELL)
	plane.material = load(GRASS_MATERIAL)
	return [plane, Transform3D(), []]


## Spinnweben: senkrechte Fläche quer über der Ecke bei −X und −Z, oben an der Wand.
func _cobweb_piece() -> Array:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 2.4)
	quad.material = load(COBWEB_MATERIAL)
	return [quad, _t(Vector3(-1.2, 2.9, -1.2), 45), []]


func _add_item(
	library: MeshLibrary, id: int, item_name: String, pieces: Array, boxes: Array
) -> bool:
	var mesh := _merge(pieces)
	if mesh == null:
		push_error("Item %s: kein Mesh" % item_name)
		return false
	var mesh_path := MESH_DIR + item_name + ".res"
	if not _save(mesh, mesh_path):
		return false
	mesh = load(mesh_path) as ArrayMesh
	var shapes := []
	for box: Array in boxes:
		var shape := BoxShape3D.new()
		shape.size = box[0]
		shapes.append(shape)
		shapes.append(Transform3D(Basis(), box[1]))
	library.create_item(id)
	library.set_item_name(id, item_name)
	library.set_item_mesh(id, mesh)
	library.set_item_shapes(id, shapes)
	if item_name in PROP_SCENES:
		return _save_prop_scene(item_name, mesh, shapes)
	return true


## Fügt alle Teile zu einem Mesh zusammen: eine Fläche je Material.
func _merge(pieces: Array) -> ArrayMesh:
	var tools: Dictionary[Material, SurfaceTool] = {}
	for piece: Array in pieces:
		var xform: Transform3D = piece[1]
		if piece[0] is Mesh:
			_append(tools, piece[0] as Mesh, xform, null)
			continue
		var root := _instance(String(piece[0]))
		if root == null:
			return null
		for node in root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.name in piece[2]:
				continue
			var local := _relative_transform(root, mesh_instance)
			_append(tools, mesh_instance.mesh, xform * local, mesh_instance)
	var result := ArrayMesh.new()
	for material: Material in tools:
		var tool := tools[material]
		tool.set_material(material)
		tool.commit(result)
	return result if result.get_surface_count() > 0 else null


func _append(
	tools: Dictionary[Material, SurfaceTool],
	mesh: Mesh,
	xform: Transform3D,
	owner_instance: MeshInstance3D
) -> void:
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface)
		if owner_instance and owner_instance.get_surface_override_material(surface):
			material = owner_instance.get_surface_override_material(surface)
		if not tools.has(material):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[material] = tool
		tools[material].append_from(mesh, surface, xform)


func _instance(path: String) -> Node3D:
	if _scene_cache.has(path):
		return _scene_cache[path]
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Fehlt: %s" % path)
		return null
	var root := scene.instantiate() as Node3D
	_scene_cache[path] = root
	return root


## Lage eines Knotens relativ zur Wurzel seiner Szene (ohne Szenenbaum).
func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var xform := Transform3D()
	var current: Node = node
	while current != root and current is Node3D:
		xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform


## Requisite als eigene Szene: Wurzel StaticBody3D mit Mesh und Kollision.
func _save_prop_scene(item_name: String, mesh: ArrayMesh, shapes: Array) -> bool:
	var root := StaticBody3D.new()
	root.name = item_name.to_pascal_case()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = &"Mesh"
	mesh_instance.mesh = mesh
	root.add_child(mesh_instance)
	mesh_instance.owner = root
	for i in range(0, shapes.size(), 2):
		var collision := CollisionShape3D.new()
		collision.name = &"Collision%d" % (i / 2)
		collision.shape = shapes[i]
		collision.transform = shapes[i + 1]
		root.add_child(collision)
		collision.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return _save(packed, PROP_DIR + item_name.trim_prefix("prop_") + ".tscn")


func _save(resource: Resource, path: String) -> bool:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		push_error("Speichern fehlgeschlagen: %s (%s)" % [path, error_string(error)])
		return false
	resource.take_over_path(path)
	return true
