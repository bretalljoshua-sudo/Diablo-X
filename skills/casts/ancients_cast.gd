class_name AncientsCast
extends SkillCast
## Zorn der Ahnen: der Krieger ruft die Ahnen, die am Zielpunkt (höchstens attack_range)
## nacheinander einschlagen (AncientStrikesCast). Die Figur ist nur für cast_time gesperrt.
##
## Parameter: cast_time, strikes, strike_interval, first_delay, knockback.
## Aspekte: extra_ancients (mehr Einschläge), damage_bonus_percent.
## Verbesserung: upgrade_armor_bonus für upgrade_armor_duration Sekunden.

const BUFF_KEY := &"skill:ancients"

var _duration: float = 0.5


func start() -> void:
	var point := clamp_point(target_point, skill.attack_range)
	face(point)
	_duration = skill.get_param(&"cast_time", 0.5)
	play_animation(_duration)
	user.add_background(AncientStrikesCast.new().setup(user, skill, mods, point))
	var armor := skill.get_param(&"upgrade_armor_bonus")
	if mods.upgraded and armor > 0.0:
		user.apply_buff(
			BUFF_KEY,
			StatBlock.from_dict({Enums.Stat.ARMOR: armor}),
			skill.get_param(&"upgrade_armor_duration", 6.0)
		)


func physics(delta: float) -> void:
	elapsed += delta
	if elapsed >= _duration:
		finish()
