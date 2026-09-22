class_name VfxEffect
extends Node3D
## Ein Effekt aus der Bibliothek (VfxLibrary): Partikel-Emitter, optional ein kurzes Lichtblitzen
## und ein sich ausbreitender Ring. Wird aus einem Pool wiederverwendet: play() startet ihn neu,
## nach lifetime Sekunden meldet er finished und schaltet sich ab.

signal finished(effect: VfxEffect)

var key: StringName = &""
## Gesamtdauer bis zur Rückgabe an den Pool.
var lifetime: float = 1.0
var emitters: Array[GPUParticles3D] = []
var flash_light: OmniLight3D
var flash_energy: float = 0.0
var ring: MeshInstance3D
var ring_radius: float = 0.0
## Figur, der der Effekt folgt (zum Beispiel Wirbelsturm), sonst null.
var follow: Node3D

var _time_left: float = 0.0
var _age: float = 0.0
var _active: bool = false


func _ready() -> void:
	set_process(_active)


## Startet den Effekt an position, ausgerichtet nach direction (Flugrichtung, darf ZERO sein).
## scale_factor vergrößert Partikel und Ring (kritische Treffer).
func play(
	at: Vector3, direction: Vector3 = Vector3.ZERO, scale_factor: float = 1.0, target: Node3D = null
) -> void:
	_active = true
	visible = true
	follow = target
	global_position = at
	scale = Vector3.ONE * scale_factor
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() > 0.0001:
		look_at(at + flat.normalized(), Vector3.UP)
	else:
		rotation = Vector3.ZERO
	_time_left = lifetime
	_age = 0.0
	for emitter in emitters:
		emitter.emitting = false
		emitter.restart()
		emitter.emitting = true
	if flash_light != null:
		flash_light.light_energy = flash_energy
		flash_light.visible = true
	if ring != null:
		ring.visible = true
		ring.scale = Vector3.ONE * 0.1
	set_process(true)


## Beendet den Effekt sofort und gibt ihn frei.
func stop() -> void:
	if not _active:
		return
	_active = false
	for emitter in emitters:
		emitter.emitting = false
	visible = false
	follow = null
	set_process(false)
	finished.emit(self)


func is_active() -> bool:
	return _active


func get_age() -> float:
	return _age


func _process(delta: float) -> void:
	_age += delta
	_time_left -= delta
	if is_instance_valid(follow):
		global_position = follow.global_position
	if flash_light != null and flash_light.visible:
		var t := clampf(_age / 0.18, 0.0, 1.0)
		flash_light.light_energy = flash_energy * (1.0 - t) * (1.0 - t)
		flash_light.visible = t < 1.0
	if ring != null and ring.visible:
		var r := clampf(_age / 0.35, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - r, 3.0)
		ring.scale = Vector3.ONE * maxf(eased * ring_radius, 0.01)
		(ring.material_override as StandardMaterial3D).albedo_color.a = 0.55 * (1.0 - r)
		ring.visible = r < 1.0
	if _time_left <= 0.0:
		stop()
