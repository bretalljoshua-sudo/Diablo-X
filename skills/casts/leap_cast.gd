class_name LeapCast
extends SkillCast
## Sprung zum Zielpunkt (höchstens attack_range), Landung trifft alles im Umkreis radius.
## Während des Flugs geht es über Gegner hinweg, Wände halten auf.
##
## Parameter: air_time, land_time, leap_height, knockback, shake.
## Aspekte: stun_duration betäubt (Aspekt der Erschütterung).
## Verbesserung: upgrade_cooldown_on_hit senkt die Abklingzeit, wenn die Landung trifft.

var _air_time: float = 0.6
var _land_time: float = 0.25
var _landed: bool = false


func start() -> void:
	var destination := clamp_point(target_point, skill.attack_range)
	face(destination)
	_air_time = skill.get_param(&"air_time", 0.6)
	_land_time = skill.get_param(&"land_time", 0.25)
	var travel := destination - player.global_position
	travel.y = 0.0
	player.cast_velocity = travel / _air_time
	player.collision_mask = PhysicsLayers.WORLD
	play_animation(_air_time + _land_time)


func physics(delta: float) -> void:
	elapsed += delta
	if not _landed:
		var t := clampf(elapsed / _air_time, 0.0, 1.0)
		player.model_root.position.y = sin(t * PI) * skill.get_param(&"leap_height", 1.6)
		if elapsed >= _air_time:
			_land()
	if elapsed >= _air_time + _land_time:
		finish()


func _land() -> void:
	_landed = true
	player.cast_velocity = Vector3.ZERO
	player.model_root.position.y = 0.0
	player.collision_mask = Player.BODY_MASK
	var center := player.global_position
	var results := hit_targets(
		enemies_in_radius(center, skill.radius),
		skill.damage_multiplier,
		skill.get_param(&"knockback", 1.0)
	)
	Combat.hit_stop_for(results)
	SkillFx.shake(skill.get_param(&"shake", 0.35), 0.3)
	spawn_fx(center, skill.radius, Color(0.9, 0.6, 0.3, 0.45))
	var reduction := skill.get_param(&"upgrade_cooldown_on_hit")
	if mods.upgraded and reduction > 0.0 and enemies_hit > 0:
		user.reduce_cooldown(skill, reduction)


func _cleanup() -> void:
	player.cast_velocity = Vector3.ZERO
	player.model_root.position.y = 0.0
	if player.state != Player.State.DODGING:
		player.collision_mask = Player.BODY_MASK
