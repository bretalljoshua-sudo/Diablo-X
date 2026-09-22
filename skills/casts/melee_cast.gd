class_name MeleeCast
extends SkillCast
## Nahkampfschlag im Bogen vor der Figur (Hieb, Spaltschlag).
##
## Parameter: cast_time (Dauer bei 1 Angriff pro Sekunde, wird durch ATTACK_SPEED geteilt),
## hit_ratio (Treffermoment ohne Animation), arc_degrees, knockback.
## Verbesserung: upgrade_combo_every + upgrade_combo_damage (jeder n-te Schlag rundherum und
## stärker), upgrade_slow + upgrade_slow_duration (verlangsamt, siehe SkillCast).

var _duration: float = 0.5
var _hit_time: float = 0.2
var _hit_done: bool = false


func start() -> void:
	face(target_point)
	var attack_speed := maxf(Stats.get_stat(player, Enums.Stat.ATTACK_SPEED), 0.1)
	_duration = skill.get_param(&"cast_time", 1.0) / attack_speed
	_hit_time = play_animation(_duration)
	if _hit_time < 0.0:
		_hit_time = _duration * skill.get_param(&"hit_ratio", 0.45)


func physics(delta: float) -> void:
	elapsed += delta
	if not _hit_done and elapsed >= _hit_time:
		strike()
	if elapsed >= _duration:
		finish()


func on_hit_frame() -> void:
	if not _hit_done:
		strike()


## Treffermoment: alle Gegner im Bogen. Liefert die getroffenen Figuren. Der Standardangriff
## des Spielers (Hieb auf Linksklick) ruft das direkt auf.
func strike() -> Array[Node3D]:
	_hit_done = true
	var arc := skill.get_param(&"arc_degrees", 120.0)
	var multiplier := skill.damage_multiplier
	var every := int(skill.get_param(&"upgrade_combo_every"))
	if mods.upgraded and every > 0 and user.count_combo(skill) % every == 0:
		arc = 360.0
		multiplier *= skill.get_param(&"upgrade_combo_damage", 1.5)
		spawn_fx(player.global_position, skill.attack_range + 0.5, Color(1.0, 0.8, 0.4, 0.5))
	var targets := enemies_in_arc(player.global_position, player.facing, skill.attack_range, arc)
	var results := hit_targets(targets, multiplier, skill.get_param(&"knockback", 0.5))
	Combat.hit_stop_for(results)
	var landed: Array[Node3D] = []
	for i in results.size():
		if results[i].amount > 0.0:
			landed.append(targets[i])
	return landed
