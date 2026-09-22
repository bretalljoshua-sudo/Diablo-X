class_name CameraRig
extends Node3D
## Kamera mit festem isometrischem Winkel, weichem Folgen und Wackeln.
## ERSATZVERSION aus AP0. AP1 baut sie aus (Zoom, Kollision, bessere Wackel-Kurven);
## die öffentlichen Funktionen shake(), screen_to_ground() und get_active() bleiben.

const GROUP := &"camera_rig"

## Figur, der die Kamera folgt. Leer = Kamera bleibt stehen.
@export var target: Node3D
@export var yaw_degrees: float = 45.0
@export var pitch_degrees: float = -55.0
@export var distance: float = 18.0
@export var fov: float = 40.0
## Wie schnell die Kamera dem Ziel folgt (höher = straffer).
@export var follow_speed: float = 8.0

var camera: Camera3D

var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_time_left: float = 0.0


## Die Kamera der aktuellen Szene, oder null.
static func get_active() -> CameraRig:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP) as CameraRig


func _ready() -> void:
	add_to_group(GROUP)
	camera = get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	camera.fov = fov
	camera.current = true
	if is_instance_valid(target):
		global_position = target.global_position
	_update_camera(Vector3.ZERO)


func _process(delta: float) -> void:
	if is_instance_valid(target):
		var weight := 1.0 - exp(-follow_speed * delta)
		global_position = global_position.lerp(target.global_position, weight)
	var offset := Vector3.ZERO
	if _shake_time_left > 0.0:
		_shake_time_left -= delta
		var falloff := clampf(_shake_time_left / _shake_duration, 0.0, 1.0)
		offset = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake_strength * falloff
	_update_camera(offset)


## Lässt die Kamera wackeln. strength in Metern, duration in Sekunden.
func shake(strength: float = 0.3, duration: float = 0.25) -> void:
	if strength >= _shake_strength * clampf(_shake_time_left / maxf(_shake_duration, 0.001), 0, 1):
		_shake_strength = strength
		_shake_duration = maxf(duration, 0.001)
		_shake_time_left = _shake_duration


## Punkt auf dem Boden (Höhe ground_y) unter einer Bildschirmposition, zum Beispiel der Maus.
## Liefert Vector3.INF, wenn der Strahl den Boden nicht trifft.
func screen_to_ground(screen_position: Vector2, ground_y: float = 0.0) -> Vector3:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var hit: Variant = Plane(Vector3.UP, ground_y).intersects_ray(origin, direction)
	return hit if hit != null else Vector3.INF


func _update_camera(shake_offset: Vector3) -> void:
	var rotation_basis := Basis.from_euler(
		Vector3(deg_to_rad(pitch_degrees), deg_to_rad(yaw_degrees), 0.0)
	)
	var local_offset := Vector3(0, 0, distance) + shake_offset
	camera.transform = Transform3D(rotation_basis, rotation_basis * local_offset)
