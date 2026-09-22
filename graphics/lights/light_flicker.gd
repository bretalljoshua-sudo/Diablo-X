class_name LightFlicker
extends Node
## Lässt das Eltern-Licht wie eine Flamme flackern (Energie und leicht die Position).
## Hängt als Kind an einem Light3D. Ruht, wenn das Licht unsichtbar ist.

## Grundenergie; 0 = Energie des Lichts beim Start.
@export var base_energy: float = 0.0
## Stärke des Flackerns als Anteil der Grundenergie.
@export_range(0.0, 1.0) var amount: float = 0.18
@export var speed: float = 9.0
## Wie weit das Licht wackelt (Meter), damit Schatten lebendig wirken.
@export var wobble: float = 0.04

var _light: Light3D
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _origin: Vector3


func _ready() -> void:
	_light = get_parent() as Light3D
	if _light == null:
		set_process(false)
		return
	if base_energy <= 0.0:
		base_energy = _light.light_energy
	_origin = _light.position
	_noise.seed = randi()
	_noise.frequency = 1.0
	_time = randf() * 100.0


func _process(delta: float) -> void:
	if not _light.visible:
		return
	_time += delta * speed
	var n := _noise.get_noise_1d(_time)
	var fast := _noise.get_noise_1d(_time * 3.1 + 50.0) * 0.35
	_light.light_energy = base_energy * (1.0 + (n + fast) * amount)
	if wobble > 0.0:
		_light.position = (
			_origin
			+ (
				Vector3(_noise.get_noise_1d(_time + 20.0), 0.0, _noise.get_noise_1d(_time + 40.0))
				* wobble
			)
		)
