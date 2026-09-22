class_name ShoutCast
extends SkillCast
## Kriegsschrei: kurzer Ruf, stärkt den Krieger für eine Weile und baut Wut auf.
##
## Parameter: cast_time, duration (Buff), damage_bonus und armor_bonus (Anteile, 0.2 = +20 %),
## buff_per_rank (Zuwachs der Buffwerte je Rang über 1).
## Aspekte: fire_damage_percent + duration entfachen einen Feuerring (FireRingCast).
## Verbesserung: upgrade_heal_percent heilt sofort.

const BUFF_KEY := &"skill:shout"

var _duration: float = 0.4


func start() -> void:
	_duration = skill.get_param(&"cast_time", 0.4)
	play_animation(_duration)
	var scale := 1.0 + skill.get_param(&"buff_per_rank") * (mods.rank - 1)
	var buff := (
		StatBlock
		. from_dict(
			{
				Enums.Stat.DAMAGE: skill.get_param(&"damage_bonus", 0.2) * scale,
				Enums.Stat.ARMOR: skill.get_param(&"armor_bonus", 0.3) * scale,
			}
		)
	)
	user.apply_buff(BUFF_KEY, buff, skill.get_param(&"duration", 8.0))
	generate_resource()
	var heal := skill.get_param(&"upgrade_heal_percent")
	if mods.upgraded and heal > 0.0:
		player.health.heal(player.health.maximum * heal / 100.0)
	if mods.fire_ring_ratio > 0.0:
		user.add_background(FireRingCast.new().setup(user, skill, mods, player.global_position))
	spawn_fx(player.global_position, 4.0, Color(1.0, 0.35, 0.15, 0.35))
	SkillFx.shake(0.15, 0.2)


func physics(delta: float) -> void:
	elapsed += delta
	if elapsed >= _duration:
		finish()
