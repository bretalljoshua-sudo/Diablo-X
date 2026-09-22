class_name FireRingCast
extends SkillCast
## Feuerring um den Krieger (Aspekt des Flammenschreis): für mods.fire_ring_duration Sekunden
## jede Sekunde mods.fire_ring_ratio × Waffenschaden als Feuerschaden an Gegnern im Umkreis.
## Radius: Parameter fire_ring_radius des auslösenden Skills (Standard 3,5 m).

const TICK_INTERVAL := 1.0

var _tick_left: float = 0.0


func locks_player() -> bool:
	return false


func physics(delta: float) -> void:
	elapsed += delta
	_tick_left -= delta
	if _tick_left <= 0.0 and elapsed <= mods.fire_ring_duration + 0.001:
		_tick_left += TICK_INTERVAL
		var radius := skill.get_param(&"fire_ring_radius", 3.5)
		var center := player.global_position
		hit_targets(
			enemies_in_radius(center, radius),
			mods.fire_ring_ratio * TICK_INTERVAL,
			0.0,
			Enums.DamageType.FIRE
		)
		SkillFx.spawn(player.get_parent(), &"fire_ring", center, radius, Color(1, 0.4, 0.1, 0.35))
	if elapsed >= mods.fire_ring_duration:
		finish()
