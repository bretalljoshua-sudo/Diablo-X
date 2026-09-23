class_name BossGate
extends StaticBody3D
## Gitter mit rotem Siegel in der Türöffnung des Bossraums. Geschlossen sperrt es den Raum
## (Kollision auf der Ebene „world“), offen liegt es im Boden.
##
## Die Durchgangsrichtung wird aus dem LevelLayout bestimmt: das Gitter steht quer zur Richtung,
## in der die Türzelle an den Bossraum grenzt.

const HEIGHT := 3.6
const WIDTH := 4.0
const THICKNESS := 0.5
const BAR_COUNT := 7
const MOVE_TIME := 0.45
const SEAL_COLOR := Color(1.0, 0.18, 0.08)

var is_closed: bool = false

var _bars: Node3D
var _seal_material: StandardMaterial3D
var _light: OmniLight3D
var _shape: CollisionShape3D
var _tween: Tween


## Baut ein Gitter am Marker boss_gate. null, wenn die Ebene keinen hat.
static func create_for(layout: LevelLayout) -> BossGate:
	if layout == null or not layout.markers.has(&"boss_gate"):
		return null
	var gate := BossGate.new()
	gate.name = "BossGate"
	gate.position = layout.markers[&"boss_gate"]
	gate.rotation.y = passage_angle(layout)
	return gate


## Winkel um y, sodass das Gitter (entlang lokal X) quer zum Durchgang steht. Der Durchgang läuft
## entlang der Achse, auf der beide Nachbarzellen begehbar sind.
static func passage_angle(layout: LevelLayout) -> float:
	var cell := WorldTiles.world_to_cell(layout.markers[&"boss_gate"], layout.cell_size)
	if _walkable(layout, cell + Vector2i(1, 0)) and _walkable(layout, cell + Vector2i(-1, 0)):
		return PI * 0.5
	return 0.0


static func _walkable(layout: LevelLayout, cell: Vector2i) -> bool:
	var key := Vector3i(cell.x, 0, cell.y)
	return layout.cells.has(key) and WorldTiles.is_walkable_cell(layout.cells[key])


func _init() -> void:
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, HEIGHT, THICKNESS)
	_shape.shape = box
	_shape.position.y = HEIGHT * 0.5
	_shape.disabled = true
	add_child(_shape)
	_bars = Node3D.new()
	_bars.name = "Bars"
	add_child(_bars)
	_build_bars()
	_light = OmniLight3D.new()
	_light.light_color = SEAL_COLOR
	_light.light_energy = 0.0
	_light.omni_range = 6.0
	_light.position = Vector3(0, 1.6, 0)
	add_child(_light)
	_bars.position.y = -HEIGHT - 0.2
	_bars.visible = false


func close() -> void:
	if is_closed:
		return
	is_closed = true
	_shape.set_deferred(&"disabled", false)
	_bars.visible = true
	_animate(0.0, 1.8, 0.85)


func open() -> void:
	if not is_closed:
		return
	is_closed = false
	_shape.set_deferred(&"disabled", true)
	_animate(-HEIGHT - 0.2, 0.0, 0.0)


func _animate(bars_y: float, light_energy: float, seal_alpha: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		_bars.position.y = bars_y
		_light.light_energy = light_energy
		_seal_material.albedo_color.a = seal_alpha
		_bars.visible = is_closed
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_bars, "position:y", bars_y, MOVE_TIME)
	_tween.tween_property(_light, "light_energy", light_energy, MOVE_TIME)
	_tween.tween_property(_seal_material, "albedo_color:a", seal_alpha, MOVE_TIME)
	if not is_closed:
		_tween.chain().tween_callback(func() -> void: _bars.visible = false)


func _build_bars() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.15, 0.15)
	iron.metallic = 0.8
	iron.roughness = 0.45
	var bar_mesh := CylinderMesh.new()
	bar_mesh.top_radius = 0.07
	bar_mesh.bottom_radius = 0.07
	bar_mesh.height = HEIGHT
	bar_mesh.radial_segments = 8
	bar_mesh.material = iron
	for i in BAR_COUNT:
		var bar := MeshInstance3D.new()
		bar.mesh = bar_mesh
		bar.position = Vector3(
			lerpf(-WIDTH * 0.42, WIDTH * 0.42, i / (BAR_COUNT - 1.0)), HEIGHT * 0.5, 0
		)
		_bars.add_child(bar)
	var cross_mesh := BoxMesh.new()
	cross_mesh.size = Vector3(WIDTH * 0.9, 0.14, 0.14)
	cross_mesh.material = iron
	for y: float in [0.6, HEIGHT - 0.5]:
		var cross := MeshInstance3D.new()
		cross.mesh = cross_mesh
		cross.position.y = y
		_bars.add_child(cross)
	_seal_material = StandardMaterial3D.new()
	_seal_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_seal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_seal_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_seal_material.albedo_color = Color(SEAL_COLOR.r, SEAL_COLOR.g, SEAL_COLOR.b, 0.0)
	_seal_material.emission_enabled = true
	_seal_material.emission = SEAL_COLOR
	_seal_material.emission_energy_multiplier = 1.5
	var seal_mesh := QuadMesh.new()
	seal_mesh.size = Vector2(WIDTH * 0.92, HEIGHT * 0.95)
	var seal := MeshInstance3D.new()
	seal.name = "Seal"
	seal.mesh = seal_mesh
	seal.material_override = _seal_material
	seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seal.position.y = HEIGHT * 0.5
	_bars.add_child(seal)
