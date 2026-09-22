class_name CharacterPreview
extends SubViewportContainer
## Figurvorschau im Inventar: eigene kleine 3D-Welt mit Licht und der Figur, dreht sich langsam,
## mit der Maus ziehen dreht sie von Hand.
##
## Lädt assets/characters/warrior.tscn (AP8), sonst eine Platzhalterfigur, an der angelegte
## Gegenstände als farbige Teile (Farbe nach Seltenheit) sichtbar werden.

const WARRIOR_SCENE := "res://assets/characters/warrior.tscn"
const SPIN_SPEED := 0.35

var viewport: SubViewport
var camera: Camera3D
var pivot: Node3D
## Platzhalterteile je Platz (nur ohne echtes Modell).
var pieces: Dictionary[Enums.Slot, MeshInstance3D] = {}
var uses_real_model: bool = false

var _dragging: bool = false


func _init() -> void:
	name = "CharacterPreview"
	stretch = true
	custom_minimum_size = Vector2(190, 300)
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	_build_world()


func _ready() -> void:
	if uses_real_model:
		frame_model()


## Richtet die Kamera so aus, dass die ganze Figur ins Bild passt (Modelle von AP8 sind
## unterschiedlich groß).
func frame_model() -> void:
	var bounds := AABB()
	var first := true
	for node in pivot.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		if not visual.is_visible_in_tree():
			continue
		var box := visual.global_transform * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first or bounds.size.y <= 0.01:
		return
	var center := bounds.get_center()
	var half_height := maxf(bounds.size.y, bounds.size.x) * 0.58
	var distance := half_height / tan(deg_to_rad(camera.fov * 0.5)) + bounds.size.z
	camera.look_at_from_position(center + Vector3(0, bounds.size.y * 0.08, distance), center)


func _process(delta: float) -> void:
	if not _dragging and is_visible_in_tree():
		pivot.rotate_y(SPIN_SPEED * delta)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		pivot.rotate_y((event as InputEventMouseMotion).relative.x * 0.01)
		accept_event()


## Zeigt die angelegten Gegenstände an der Figur.
func show_equipment(equipment: Equipment) -> void:
	if uses_real_model:
		return
	for slot: Enums.Slot in pieces:
		var item := equipment.get_item(slot) if equipment != null else null
		var piece := pieces[slot]
		piece.visible = item != null
		if item != null:
			var material := piece.material_override as StandardMaterial3D
			var color := ItemText.rarity_color(item.rarity)
			material.albedo_color = color.darkened(0.35)
			material.emission = color
			material.emission_energy_multiplier = 0.25 if item.rarity >= Enums.Rarity.RARE else 0.0


func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.33, 0.4)
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	viewport.add_child(world_env)

	camera = Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0, 1.1, 4.6)
	camera.look_at_from_position(camera.position, Vector3(0, 0.95, 0))
	viewport.add_child(camera)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.82, 0.6)
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-35, 35, 0)
	viewport.add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.5, 0.6, 1.0)
	rim.light_energy = 2.0
	rim.omni_range = 5.0
	rim.position = Vector3(-1.2, 2.0, -1.5)
	viewport.add_child(rim)

	pivot = Node3D.new()
	pivot.name = "Pivot"
	viewport.add_child(pivot)
	if ResourceLoader.exists(WARRIOR_SCENE):
		var scene := load(WARRIOR_SCENE) as PackedScene
		if scene != null:
			pivot.add_child(scene.instantiate())
			uses_real_model = true
			return
	_build_placeholder()


func _build_placeholder() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	body.mesh = capsule
	body.position.y = 0.85
	body.material_override = _material(Color(0.32, 0.25, 0.22))
	pivot.add_child(body)
	_add_piece(Enums.Slot.HELM, _sphere(0.24), Vector3(0, 1.62, 0))
	_add_piece(Enums.Slot.CHEST, _box(Vector3(0.72, 0.62, 0.46)), Vector3(0, 1.15, 0))
	_add_piece(Enums.Slot.PANTS, _box(Vector3(0.6, 0.5, 0.42)), Vector3(0, 0.55, 0))
	_add_piece(Enums.Slot.BOOTS, _box(Vector3(0.62, 0.2, 0.5)), Vector3(0, 0.1, 0.03))
	_add_piece(Enums.Slot.GLOVES, _box(Vector3(0.95, 0.16, 0.2)), Vector3(0, 0.82, 0.1))
	_add_piece(Enums.Slot.AMULET, _sphere(0.07), Vector3(0, 1.38, 0.26))
	_add_piece(Enums.Slot.RING_1, _sphere(0.05), Vector3(-0.46, 0.82, 0.12))
	_add_piece(Enums.Slot.RING_2, _sphere(0.05), Vector3(0.46, 0.82, 0.12))
	var weapon := _add_piece(
		Enums.Slot.WEAPON, _box(Vector3(0.08, 1.2, 0.05)), Vector3(0.55, 1.0, 0.2)
	)
	weapon.rotation_degrees.z = -15.0
	show_equipment(null)


func _add_piece(slot: Enums.Slot, mesh: Mesh, position: Vector3) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = String(Enums.Slot.keys()[slot]).to_pascal_case()
	piece.mesh = mesh
	piece.position = position
	piece.material_override = _material(Color.GRAY)
	pivot.add_child(piece)
	pieces[slot] = piece
	return piece


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.6
	material.roughness = 0.45
	material.emission_enabled = true
	material.emission = Color.BLACK
	return material


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh
