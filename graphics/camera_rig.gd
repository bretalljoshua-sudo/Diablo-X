class_name CameraRig
extends Node3D
## Kamera-Rig im Stil von Diablo: fester isometrischer Winkel, weiches Folgen mit etwas
## Vorausschau in Laufrichtung, Zoom mit dem Mausrad und Wackeln über Rauschen.
##
## Öffentliche Schnittstelle (Vertrag aus AP0, bleibt stabil):
##   CameraRig.get_active(), shake(strength, duration), screen_to_ground(screen_position, ground_y),
##   camera, target, yaw_degrees, pitch_degrees, distance, fov, follow_speed.
##
## Der Knoten selbst ist der Ankerpunkt auf dem Boden (folgt dem Ziel), die Kamera hängt daran.
## Wackeln verschiebt nur die Kamera, nie den Anker.

const GROUP := &"camera_rig"
## Weiter als so viele Meter in einem Bild gilt als Sprung, dann springt die Kamera mit.
const TELEPORT_DISTANCE := 5.0

## Figur, der die Kamera folgt. Leer = Kamera bleibt stehen.
@export var target: Node3D
@export var yaw_degrees: float = 45.0
@export var pitch_degrees: float = -52.0
## Abstand der Kamera zum Anker in Metern. Setzen wirkt als Zoomziel, der Übergang ist weich.
@export var distance: float = 19.0:
	set(value):
		distance = value
		_zoom_goal = value
@export var fov: float = 40.0
## Wie schnell die Kamera dem Ziel folgt (höher = straffer).
@export var follow_speed: float = 8.0

@export_group("Zoom")
## Mausrad-Zoom an oder aus.
@export var zoom_enabled: bool = true
@export var zoom_min: float = 10.0
@export var zoom_max: float = 26.0
## Meter pro Mausrad-Raste.
@export var zoom_step: float = 1.5
@export var zoom_speed: float = 10.0

@export_group("Vorausschau")
## Wie weit die Kamera in Laufrichtung vorausschaut (Meter bei voller Laufgeschwindigkeit).
@export var look_ahead: float = 1.2
## Laufgeschwindigkeit, ab der die volle Vorausschau gilt.
@export var look_ahead_speed: float = 6.0
@export var look_ahead_smoothing: float = 3.0

@export_group("Wackeln")
## Stärkstes Wackeln in Metern, egal wie viele Stöße zusammenkommen.
@export var max_shake: float = 0.8
## Leichte Drehung um die Blickachse beim Wackeln (Grad pro Meter Wackelstärke).
@export var shake_roll_degrees: float = 3.0
## Frequenz des Wackelrauschens.
@export var shake_frequency: float = 22.0
## Globaler Faktor, zum Beispiel aus den Einstellungen (0 = kein Wackeln).
@export_range(0.0, 2.0) var shake_scale: float = 1.0

var camera: Camera3D

var _zoom_goal: float = 19.0
var _current_distance: float = 19.0
var _look_offset: Vector3 = Vector3.ZERO
var _last_target_position: Vector3 = Vector3.INF
var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_time_left: float = 0.0
var _shake_time: float = 0.0
var _noise := FastNoiseLite.new()


## Die Kamera der aktuellen Szene, oder null.
static func get_active() -> CameraRig:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP) as CameraRig


func _ready() -> void:
	add_to_group(GROUP)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = 1234
	camera = get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	camera.fov = fov
	camera.near = 0.3
	camera.far = 400.0
	camera.current = true
	_current_distance = distance
	_zoom_goal = distance
	snap_to_target()


func _process(delta: float) -> void:
	# Trefferstopp (AP2) senkt Engine.time_scale; Kamera und Wackeln laufen in Echtzeit weiter.
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	_follow(real_delta)
	_current_distance = lerpf(_current_distance, _zoom_goal, 1.0 - exp(-zoom_speed * real_delta))
	_update_camera(_shake_offset(real_delta))


func _unhandled_input(event: InputEvent) -> void:
	if not zoom_enabled:
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_by(-zoom_step * maxf(button.factor, 1.0))
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_by(zoom_step * maxf(button.factor, 1.0))


## Setzt den Anker sofort auf das Ziel (nach Teleport oder Ebenenwechsel).
func snap_to_target() -> void:
	_look_offset = Vector3.ZERO
	if is_instance_valid(target):
		global_position = target.global_position
		_last_target_position = target.global_position
	else:
		_last_target_position = Vector3.INF
	if camera != null:
		_update_camera(Vector3.ZERO)


## Ändert den Zoom um amount Meter (positiv = weiter weg), begrenzt auf zoom_min bis zoom_max.
func zoom_by(amount: float) -> void:
	_zoom_goal = clampf(_zoom_goal + amount, zoom_min, zoom_max)


## Aktueller Abstand der Kamera (während eines Zoom-Übergangs zwischen alt und distance).
func get_current_distance() -> float:
	return _current_distance


## Lässt die Kamera wackeln. strength in Metern, duration in Sekunden.
## Ein schwächerer Stoß während eines stärkeren wird ignoriert, ein stärkerer ersetzt ihn.
func shake(strength: float = 0.3, duration: float = 0.25) -> void:
	strength = minf(strength * shake_scale, max_shake)
	if strength <= 0.0:
		return
	if strength >= get_shake_strength():
		_shake_strength = strength
		_shake_duration = maxf(duration, 0.001)
		_shake_time_left = _shake_duration


## Aktuelle Wackelstärke in Metern (fällt über die Dauer quadratisch ab).
func get_shake_strength() -> float:
	if _shake_time_left <= 0.0:
		return 0.0
	var falloff := clampf(_shake_time_left / _shake_duration, 0.0, 1.0)
	return _shake_strength * falloff * falloff


## Punkt auf dem Boden (Höhe ground_y) unter einer Bildschirmposition, zum Beispiel der Maus.
## Liefert Vector3.INF, wenn der Strahl den Boden nicht trifft.
func screen_to_ground(screen_position: Vector2, ground_y: float = 0.0) -> Vector3:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var hit: Variant = Plane(Vector3.UP, ground_y).intersects_ray(origin, direction)
	return hit if hit != null else Vector3.INF


## Richtung der Kamera auf dem Boden (Bildschirm-oben), normiert.
func get_ground_forward() -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(yaw_degrees)) * Vector3.FORWARD


func _follow(real_delta: float) -> void:
	if not is_instance_valid(target):
		_last_target_position = Vector3.INF
		return
	var target_position := target.global_position
	var wanted_offset := Vector3.ZERO
	if _last_target_position != Vector3.INF and real_delta > 0.0:
		var step := target_position - _last_target_position
		step.y = 0.0
		if step.length() > TELEPORT_DISTANCE:
			# Sprung (Teleport, Ebenenwechsel): sofort hin, keine Vorausschau.
			global_position = target_position
			_look_offset = Vector3.ZERO
		elif look_ahead > 0.0:
			var velocity := step / real_delta
			wanted_offset = velocity.limit_length(look_ahead_speed) / look_ahead_speed * look_ahead
	_last_target_position = target_position
	_look_offset = _look_offset.lerp(wanted_offset, 1.0 - exp(-look_ahead_smoothing * real_delta))
	var goal := target_position + _look_offset
	global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * real_delta))


func _shake_offset(real_delta: float) -> Vector3:
	if _shake_time_left <= 0.0:
		return Vector3.ZERO
	_shake_time_left -= real_delta
	_shake_time += real_delta * shake_frequency
	var strength := get_shake_strength()
	return (
		Vector3(
			_noise.get_noise_2d(_shake_time, 0.0),
			_noise.get_noise_2d(0.0, _shake_time),
			_noise.get_noise_2d(_shake_time, 100.0)
		)
		* strength
	)


func _update_camera(shake_offset: Vector3) -> void:
	var rotation_basis := Basis.from_euler(
		Vector3(deg_to_rad(pitch_degrees), deg_to_rad(yaw_degrees), 0.0)
	)
	var local_offset := (
		Vector3(0, 0, _current_distance) + Vector3(shake_offset.x, shake_offset.y, 0)
	)
	var roll := deg_to_rad(shake_offset.z * shake_roll_degrees)
	camera.fov = fov
	camera.transform = Transform3D(
		rotation_basis * Basis(Vector3.BACK, roll), rotation_basis * local_offset
	)
