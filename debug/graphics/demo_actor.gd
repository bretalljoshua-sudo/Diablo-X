class_name GraphicsDemoActor
extends Node3D
## Stand-in-Gegner für die Grafik-Testszenen (AP1): zeigt ein Modell aus AP8 (sonst eine
## Kapsel), läuft im Kreis, lässt sich treffen und töten. Treffer und Tod gehen als echte
## EventBus-Signale raus, damit Vfx (Zahlen, Blut, Auflösen) genau wie im Spiel reagiert.

const MODEL_PATH := "res://assets/characters/%s.tscn"

## Name der Figur aus assets/characters/ (skeleton_swarm, ghoul, skeleton_archer, …).
@export var model_name: String = "skeleton_swarm"
## Radius des Kreises, den die Figur läuft (0 = steht).
@export var wander_radius: float = 1.5
@export var wander_speed: float = 1.2

var model: Node3D
var dead: bool = false

var _center: Vector3
var _angle: float = 0.0
var _respawn_left: float = -1.0


func _ready() -> void:
	_center = position
	_angle = randf() * TAU
	var path := MODEL_PATH % model_name
	if ResourceLoader.exists(path):
		model = (load(path) as PackedScene).instantiate() as Node3D
	else:
		var capsule := MeshInstance3D.new()
		capsule.mesh = CapsuleMesh.new()
		capsule.position = Vector3(0, 1, 0)
		model = Node3D.new()
		model.add_child(capsule)
	model.name = "Model"
	if DisplayServer.get_name() == "headless":
		# Ohne Bildschirm (Rauchtest) stumm: Dutzende gleichzeitig laufende Klänge bleiben
		# beim Beenden sonst im Audio-Server hängen und landen als Fehler im Log.
		for sound: StringName in [&"footstep_sound", &"attack_sound", &"hit_sound", &"death_sound"]:
			if sound in model:
				model.set(sound, null)
	add_child(model)
	set_meta(&"hit_height", 1.0)


func _process(delta: float) -> void:
	if dead:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			revive()
		return
	if wander_radius > 0.0:
		_angle += delta * wander_speed / wander_radius
		var offset := Vector3(cos(_angle), 0, sin(_angle)) * wander_radius
		var next := _center + offset
		var step := next - position
		position = next
		if step.length_squared() > 0.000001:
			look_at(global_position - step, Vector3.UP)
		if model.has_method(&"set_move_velocity"):
			model.call(&"set_move_velocity", wander_speed)


## Schickt einen Treffer über den EventBus (ohne echte Lebenspunkte).
func take_hit(
	source: Node3D,
	amount: float,
	crit: bool = false,
	type: Enums.DamageType = Enums.DamageType.PHYSICAL
) -> void:
	if dead:
		return
	var hit := HitInfo.create(source, self, amount, type)
	var result := DamageResult.new()
	result.amount = amount
	result.crit = crit
	EventBus.damage_dealt.emit(hit, result)
	if model.has_method(&"play_hit"):
		model.call(&"play_hit")


## Stirbt (Todesanimation und Auflösen), steht nach respawn_after Sekunden wieder auf.
func kill(source: Node3D, respawn_after: float = 3.0) -> void:
	if dead:
		return
	var hit := HitInfo.create(source, self, 999.0)
	var result := DamageResult.new()
	result.amount = 999.0
	result.crit = true
	result.killed = true
	EventBus.damage_dealt.emit(hit, result)
	dead = true
	_respawn_left = respawn_after
	if model.has_method(&"play_death"):
		model.call(&"play_death")
	EventBus.entity_died.emit(self, source)


func revive() -> void:
	dead = false
	if model.has_method(&"revive"):
		model.call(&"revive")
	EventBus.entity_spawned.emit(self)
