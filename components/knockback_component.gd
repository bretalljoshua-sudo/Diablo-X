class_name KnockbackComponent
extends Node
## Rückstoß für eine CharacterBody3D. Combat.apply_damage() ruft apply() auf, die Figur
## addiert in _physics_process() consume(delta) auf ihre Geschwindigkeit.

## 0 = voller Rückstoß, 1 = unbeweglich (zum Beispiel Bosse).
@export_range(0.0, 1.0) var resistance: float = 0.0
## Dauer eines Rückstoßes in Sekunden.
@export var duration: float = 0.18

var _start_speed: float = 0.0
var _direction: Vector3 = Vector3.ZERO
var _time_left: float = 0.0


## Stößt die Figur um distance Meter in direction (waagerecht) weg.
func apply(direction: Vector3, distance: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001 or distance <= 0.0:
		return
	var effective := distance * (1.0 - clampf(resistance, 0.0, 1.0))
	if effective <= 0.0:
		return
	_direction = flat.normalized()
	# Geschwindigkeit fällt linear auf 0; Fläche unter der Kurve = effective.
	_start_speed = 2.0 * effective / duration
	_time_left = duration


func is_active() -> bool:
	return _time_left > 0.0


## Geschwindigkeit des Rückstoßes für diesen Physik-Takt.
func consume(delta: float) -> Vector3:
	if _time_left <= 0.0:
		return Vector3.ZERO
	var speed := _start_speed * (_time_left / duration)
	_time_left -= delta
	return _direction * speed


func cancel() -> void:
	_time_left = 0.0
