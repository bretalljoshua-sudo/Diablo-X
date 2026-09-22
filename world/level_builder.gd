class_name LevelBuilder
extends RefCounted
## Baut aus einem LevelLayout die Knoten einer Ebene: GridMap für Aufbau und Requisiten,
## Navigation (zur Laufzeit gebacken) und Lichter.

const AGENT_RADIUS := 0.5
const AGENT_HEIGHT := 2.0
## Lichter mit Schatten (teuer). Die übrigen Lichter werfen keine Schatten.
const MAX_SHADOW_LIGHTS := 8
const LIGHT_FADE_BEGIN := 45.0

const LIGHT_COLORS: Dictionary[StringName, Color] = {
	&"catacombs": Color(1.0, 0.6, 0.3),
	&"boss": Color(1.0, 0.4, 0.25),
	&"village": Color(1.0, 0.75, 0.45),
}


## Baut alles unter root auf. Liefert root zurück.
static func build(layout: LevelLayout, root: Node3D) -> Node3D:
	root.add_child(build_grid(layout, layout.cells, layout.cell_orientations, "Cells"))
	root.add_child(build_grid(layout, layout.props, layout.prop_orientations, "Props"))
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	region.navigation_mesh = bake_navigation(layout)
	root.add_child(region)
	root.add_child(build_lights(layout))
	return root


static func build_grid(
	layout: LevelLayout,
	cells: Dictionary[Vector3i, int],
	orientations: Dictionary[Vector3i, int],
	node_name: String
) -> GridMap:
	var grid := GridMap.new()
	grid.name = node_name
	grid.mesh_library = WorldKit.get_library()
	grid.cell_size = layout.cell_size
	grid.cell_center_y = false
	grid.collision_layer = PhysicsLayers.WORLD
	grid.collision_mask = 0
	for cell in cells:
		var item := WorldKit.item_for(cells[cell])
		if item != GridMap.INVALID_CELL_ITEM:
			grid.set_cell_item(cell, item, orientations.get(cell, 0))
	return grid


## Backt das Navigationsnetz direkt aus den begehbaren Zellen (ohne Meshes zu lesen).
## Wände und versperrende Requisiten fehlen im Boden, der Rand wird um AGENT_RADIUS eingerückt.
static func bake_navigation(layout: LevelLayout) -> NavigationMesh:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = AGENT_RADIUS
	nav_mesh.agent_height = AGENT_HEIGHT
	nav_mesh.cell_size = ProjectSettings.get_setting("navigation/3d/default_cell_size", 0.25)
	nav_mesh.cell_height = ProjectSettings.get_setting("navigation/3d/default_cell_height", 0.25)
	var source := NavigationMeshSourceGeometryData3D.new()
	source.add_faces(floor_faces(layout), Transform3D.IDENTITY)
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source)
	return nav_mesh


## Bodendreiecke aller begehbaren Zellen. Nebeneinanderliegende Zellen einer Zeile werden
## zu einem Streifen zusammengefasst, das spart Dreiecke.
static func floor_faces(layout: LevelLayout) -> PackedVector3Array:
	var walkable := DungeonGenerator.walkable_cells(layout)
	var rows: Dictionary[int, Array] = {}
	for cell in walkable:
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)
	var faces := PackedVector3Array()
	var size := layout.cell_size
	for z: int in rows:
		var xs: Array = rows[z]
		xs.sort()
		var run_start: int = xs[0]
		var previous: int = xs[0]
		for i in range(1, xs.size() + 1):
			var x: int = xs[i] if i < xs.size() else previous + 2
			if x == previous + 1:
				previous = x
				continue
			var a := Vector3(run_start * size.x, 0, z * size.z)
			var b := Vector3((previous + 1) * size.x, 0, z * size.z)
			var c := Vector3((previous + 1) * size.x, 0, (z + 1) * size.z)
			var d := Vector3(run_start * size.x, 0, (z + 1) * size.z)
			faces.append_array([a, b, c, a, c, d])
			run_start = x
			previous = x
	return faces


static func build_lights(layout: LevelLayout) -> Node3D:
	var lights := Node3D.new()
	lights.name = "Lights"
	var color: Color = LIGHT_COLORS.get(layout.theme, LIGHT_COLORS[&"catacombs"])
	var ordered := layout.lights.duplicate()
	ordered.sort_custom(
		func(a: Vector3, b: Vector3) -> bool:
			return (
				a.distance_squared_to(layout.player_start)
				< b.distance_squared_to(layout.player_start)
			)
	)
	for i in ordered.size():
		lights.add_child(make_light(ordered[i], color, i < MAX_SHADOW_LIGHTS))
	return lights


## Einfaches Fackellicht. AP1 kann hier seine Licht-Vorlagen einsetzen.
static func make_light(position: Vector3, color: Color, shadow: bool) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = 2.4
	light.omni_range = 10.0
	light.omni_attenuation = 1.2
	light.shadow_enabled = shadow
	light.distance_fade_enabled = true
	light.distance_fade_begin = LIGHT_FADE_BEGIN
	light.distance_fade_length = 10.0
	return light
