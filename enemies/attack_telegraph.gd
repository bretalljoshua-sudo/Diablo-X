class_name AttackTelegraph
extends Node3D
## Sichtbare Vorwarnung am Boden: eine blasse Fläche zeigt, wo der Angriff trifft, eine
## kräftige Füllung wächst bis zum Treffermoment. Formen: Kreis, Kegel, Linie.
## Aktive Vorwarnungen stehen in der Gruppe GROUP; Bots und Tests fragen sie über
## contains_point() und get_time_left() ab.

enum Shape { CIRCLE, CONE, LINE }

const GROUP := &"enemy_telegraphs"
const HEIGHT := 0.04
const CONE_SEGMENTS := 18
const CIRCLE_SEGMENTS := 32
const DEFAULT_COLOR := Color(0.95, 0.12, 0.05)

static var _mesh_cache: Dictionary[String, Mesh] = {}
static var _material_cache: Dictionary[String, StandardMaterial3D] = {}

var shape: Shape = Shape.CIRCLE
var radius: float = 1.0
var arc_degrees: float = 90.0
var width: float = 0.8
var duration: float = 1.0
var elapsed: float = 0.0

var _area: MeshInstance3D
var _fill: MeshInstance3D
var _active: bool = false


func _init() -> void:
	_area = MeshInstance3D.new()
	_area.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill = MeshInstance3D.new()
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill.position.y = 0.005
	add_child(_area)
	add_child(_fill)
	visible = false
	set_process(false)
	set_physics_process(false)


## Zeigt einen Kreis mit Radius r um den Ursprung dieses Knotens.
func show_circle(r: float, time: float, color: Color = DEFAULT_COLOR) -> void:
	shape = Shape.CIRCLE
	radius = r
	_start(_circle_mesh(), Vector3(r, 1.0, r), time, color)


## Zeigt einen Kegel nach lokal −Z mit Reichweite r und Öffnungswinkel arc.
func show_cone(r: float, arc: float, time: float, color: Color = DEFAULT_COLOR) -> void:
	shape = Shape.CONE
	radius = r
	arc_degrees = arc
	_start(_cone_mesh(arc), Vector3(r, 1.0, r), time, color)


## Zeigt eine Linie nach lokal −Z mit Länge length und Breite w.
func show_line(length: float, w: float, time: float, color: Color = DEFAULT_COLOR) -> void:
	shape = Shape.LINE
	radius = length
	width = w
	_start(_line_mesh(), Vector3(w, 1.0, length), time, color)


func hide_telegraph() -> void:
	_active = false
	visible = false
	set_process(false)
	set_physics_process(false)
	if is_in_group(GROUP):
		remove_from_group(GROUP)


func is_active() -> bool:
	return _active


func get_time_left() -> float:
	return maxf(duration - elapsed, 0.0) if _active else 0.0


func get_progress() -> float:
	return clampf(elapsed / duration, 0.0, 1.0) if duration > 0.0 else 1.0


## Liegt ein Weltpunkt (plus Randabstand margin) in der gezeigten Fläche?
func contains_point(point: Vector3, margin: float = 0.0) -> bool:
	if not _active:
		return false
	var local := global_transform.affine_inverse() * point
	var flat := Vector2(local.x, local.z)
	var inside := false
	match shape:
		Shape.CIRCLE:
			inside = flat.length() <= radius + margin
		Shape.CONE:
			inside = (
				flat.length() <= radius + margin
				and (
					flat.length() <= margin + 0.25
					or absf(Vector2(0, -1).angle_to(flat)) <= deg_to_rad(arc_degrees) * 0.5
				)
			)
		Shape.LINE:
			inside = (
				local.z <= margin
				and local.z >= -radius - margin
				and absf(local.x) <= width * 0.5 + margin
			)
	return inside


# Die Zeit läuft im Physik-Takt wie der Angriff selbst, damit get_time_left() genau zum Treffer
# passt, unabhängig von der Bildrate.
func _physics_process(delta: float) -> void:
	if _active:
		elapsed += delta


func _process(_delta: float) -> void:
	if not _active:
		return
	var t := get_progress()
	match shape:
		Shape.LINE:
			_fill.scale = Vector3(width, 1.0, maxf(radius * t, 0.01))
		_:
			_fill.scale = Vector3(maxf(radius * t, 0.01), 1.0, maxf(radius * t, 0.01))


func _start(mesh: Mesh, full_scale: Vector3, time: float, color: Color) -> void:
	duration = maxf(time, 0.01)
	elapsed = 0.0
	_area.mesh = mesh
	_fill.mesh = mesh
	_area.scale = full_scale
	_fill.scale = Vector3(0.01, 1.0, 0.01)
	_area.material_override = _material(color, 0.22)
	_fill.material_override = _material(color, 0.5)
	# Mit top_level = true steht die Vorwarnung fest in der Welt (Position setzt der Aufrufer).
	if not top_level:
		position.y = HEIGHT
	_active = true
	visible = true
	set_process(true)
	set_physics_process(true)
	if not is_in_group(GROUP):
		add_to_group(GROUP)


static func _material(color: Color, alpha: float) -> StandardMaterial3D:
	var key := "%s/%.2f" % [color.to_html(false), alpha]
	if _material_cache.has(key):
		return _material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	_material_cache[key] = mat
	return mat


## Einheitskreis (Radius 1) in der xz-Ebene.
static func _circle_mesh() -> Mesh:
	var key := "circle"
	if not _mesh_cache.has(key):
		var points: PackedVector3Array = []
		for i in CIRCLE_SEGMENTS + 1:
			var a := TAU * i / CIRCLE_SEGMENTS
			points.append(Vector3(cos(a), 0.0, sin(a)))
		_mesh_cache[key] = _fan(points)
	return _mesh_cache[key]


## Einheitskegel (Reichweite 1) nach −Z.
static func _cone_mesh(arc: float) -> Mesh:
	var key := "cone/%d" % roundi(arc)
	if not _mesh_cache.has(key):
		var points: PackedVector3Array = []
		var half := deg_to_rad(arc) * 0.5
		for i in CONE_SEGMENTS + 1:
			var a := -half + 2.0 * half * i / CONE_SEGMENTS
			points.append(Vector3(sin(a), 0.0, -cos(a)))
		_mesh_cache[key] = _fan(points)
	return _mesh_cache[key]


## Einheitsrechteck: Breite 1 (x von −0,5 bis 0,5), Länge 1 (z von 0 bis −1).
static func _line_mesh() -> Mesh:
	var key := "line"
	if not _mesh_cache.has(key):
		var verts := PackedVector3Array(
			[
				Vector3(-0.5, 0, 0),
				Vector3(0.5, 0, 0),
				Vector3(0.5, 0, -1),
				Vector3(-0.5, 0, 0),
				Vector3(0.5, 0, -1),
				Vector3(-0.5, 0, -1),
			]
		)
		_mesh_cache[key] = _array_mesh(verts)
	return _mesh_cache[key]


static func _fan(rim: PackedVector3Array) -> Mesh:
	var verts: PackedVector3Array = []
	for i in rim.size() - 1:
		verts.append(Vector3.ZERO)
		verts.append(rim[i])
		verts.append(rim[i + 1])
	return _array_mesh(verts)


static func _array_mesh(verts: PackedVector3Array) -> Mesh:
	var normals: PackedVector3Array = []
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
