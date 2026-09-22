class_name AncientStrikesCast
extends SkillCast
## Die Einschläge der Ahnen am Zielpunkt, laufen nebenher (siehe AncientsCast).

var _strikes_left: int = 0
var _next_strike: float = 0.0


func locks_player() -> bool:
	return false


func start() -> void:
	_strikes_left = int(skill.get_param(&"strikes", 3.0)) + mods.extra_ancients
	_next_strike = skill.get_param(&"first_delay", 0.3)


func physics(delta: float) -> void:
	elapsed += delta
	while _strikes_left > 0 and elapsed >= _next_strike:
		_strike()
		_strikes_left -= 1
		_next_strike += skill.get_param(&"strike_interval", 0.45)
	if _strikes_left <= 0:
		finish()


func _strike() -> void:
	var targets := enemies_in_radius(target_point, skill.radius)
	var results := hit_targets(targets, skill.damage_multiplier)
	push_from(target_point, targets, maxf(skill.get_param(&"knockback", 1.5), mods.knockback))
	Combat.hit_stop_for(results)
	SkillFx.shake(0.3, 0.2)
	spawn_fx(target_point, skill.radius, Color(0.5, 0.8, 1.0, 0.5))
