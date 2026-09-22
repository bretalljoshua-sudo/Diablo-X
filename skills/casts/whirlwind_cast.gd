class_name WhirlwindCast
extends SkillCast
## Kanalisierter Wirbelsturm: solange die Taste gehalten wird, trifft er in Takten alles
## rundherum und bewegt die Figur langsam zum Zielpunkt. SkillDef.cost ist Wut pro Sekunde,
## SkillDef.damage_multiplier Schaden pro Sekunde (auf die Takte verteilt).
##
## Parameter: tick_interval, move_factor (Anteil der Laufgeschwindigkeit).
## Aspekte: pull_radius + pull_strength ziehen Gegner heran, burn_* setzt in Brand.
## Verbesserung: upgrade_resource_per_hit (Wut je getroffenem Gegner pro Takt),
## upgrade_resource_max_targets.

var _tick_left: float = 0.0


func start() -> void:
	play_animation(0.0)
	_tick_left = 0.0


func physics(delta: float) -> void:
	elapsed += delta
	var interval := skill.get_param(&"tick_interval", 0.25)
	_tick_left -= delta
	while _tick_left <= 0.0 and not finished:
		_tick_left += interval
		_tick(interval)
	if finished:
		return
	var direction := flat_direction(target_point)
	var offset := (
		target_point - player.global_position if target_point != Vector3.INF else Vector3()
	)
	offset.y = 0.0
	if direction != Vector3.ZERO and offset.length() > 0.3:
		var speed := Stats.get_stat(player, Enums.Stat.MOVE_SPEED)
		player.cast_velocity = direction * speed * skill.get_param(&"move_factor", 0.6)
		player.facing = direction
	else:
		player.cast_velocity = Vector3.ZERO
	if not SkillFx.is_playing(player.model, skill.animation):
		play_animation(0.0)


func release() -> void:
	finish()


func _tick(interval: float) -> void:
	if not user.fury.spend(skill.cost * interval):
		finish()
		return
	var center := player.global_position
	if mods.pull_strength > 0.0:
		_pull(center, mods.pull_strength * interval)
	var targets := enemies_in_radius(center, skill.radius)
	hit_targets(targets, skill.damage_multiplier * interval)
	spawn_fx(center, skill.radius, Color(0.85, 0.85, 0.9, 0.25))


## Zieht Gegner im Umkreis pull_radius um distance Meter heran (nicht in die Figur hinein).
func _pull(center: Vector3, distance: float) -> void:
	for entity in enemies_in_radius(center, mods.pull_radius):
		var offset := center - entity.global_position
		offset.y = 0.0
		var room := offset.length() - 1.0
		var knockback := Components.knockback(entity)
		if knockback != null and room > 0.05:
			knockback.apply(offset, minf(distance, room))


func _cleanup() -> void:
	player.cast_velocity = Vector3.ZERO
	SkillFx.stop(player.model)
