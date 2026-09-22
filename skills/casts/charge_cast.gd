class_name ChargeCast
extends SkillCast
## Ansturm: rennt geradeaus (höchstens attack_range), durch Gegner hindurch, trifft jeden
## Gegner auf dem Weg einmal und stößt ihn weg. Wände beenden den Ansturm.
##
## Parameter: speed (m/s), hit_radius, knockback.
## Aspekte: damage_bonus_percent und knockback (Aspekt des Sturmlaufs).
## Verbesserung: upgrade_resource_per_hit, upgrade_resource_max_targets (Wut je Gegner).

var _direction: Vector3 = Vector3.FORWARD
var _distance: float = 0.0
var _travelled: float = 0.0
var _last_position: Vector3
var _stuck_frames: int = 0
var _already_hit: Array[Node3D] = []


func start() -> void:
	_direction = face(target_point)
	var to_point := flat_direction(target_point)
	var offset := target_point - player.global_position if to_point != Vector3.ZERO else Vector3()
	offset.y = 0.0
	_distance = skill.attack_range
	if to_point != Vector3.ZERO:
		_distance = clampf(offset.length() + 1.0, 2.0, skill.attack_range)
	_last_position = player.global_position
	player.collision_mask = PhysicsLayers.WORLD
	player.cast_velocity = _direction * skill.get_param(&"speed", 18.0)
	play_animation(0.0)


func physics(delta: float) -> void:
	elapsed += delta
	var position := player.global_position
	var step := Vector2(position.x - _last_position.x, position.z - _last_position.z).length()
	_last_position = position
	_travelled += step
	var expected := skill.get_param(&"speed", 18.0) * delta
	_stuck_frames = _stuck_frames + 1 if elapsed > delta * 1.5 and step < expected * 0.2 else 0
	_hit_along_path(position)
	if _travelled >= _distance or _stuck_frames >= 3 or elapsed > 2.0:
		finish()


func _hit_along_path(position: Vector3) -> void:
	var fresh: Array[Node3D] = []
	for entity in enemies_in_radius(position, skill.get_param(&"hit_radius", 1.2)):
		if not entity in _already_hit:
			fresh.append(entity)
			_already_hit.append(entity)
	if fresh.is_empty():
		return
	var results := hit_targets(fresh, skill.damage_multiplier, skill.get_param(&"knockback", 2.0))
	Combat.hit_stop_for(results)
	spawn_fx(position, 1.2, Color(0.9, 0.9, 1.0, 0.35))


func _cleanup() -> void:
	player.cast_velocity = Vector3.ZERO
	if player.state != Player.State.DODGING:
		player.collision_mask = Player.BODY_MASK
	SkillFx.stop(player.model)
