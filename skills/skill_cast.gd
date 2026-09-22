class_name SkillCast
extends RefCounted
## Ein laufender Skill-Einsatz. SkillUser erzeugt ihn, ruft start(), dann je Physik-Takt
## physics(), bis finished true ist. Die Unterklassen in skills/casts/ bauen das Verhalten.
##
## Sperrt der Einsatz die Figur (locks_player), steht der Spieler im Zustand CASTING und
## bewegt sich nur über Player.cast_velocity. Ausweichrolle, Betäubung und Tod brechen ab
## (cancel()). Einsätze, die nicht sperren (Feuerring, Einschläge der Ahnen), laufen nebenher.

var user: SkillUser
var player: Player
var skill: SkillDef
var mods: SkillModifiers
var target_point: Vector3
var target: Node3D
## Platz der Skillleiste, von dem der Einsatz kam (-1 = Befehl ohne Platz).
var slot: int = -1
var elapsed: float = 0.0
var finished: bool = false
## Getroffene Gegner über den ganzen Einsatz.
var enemies_hit: int = 0

var _resource_generated: bool = false


func setup(
	p_user: SkillUser,
	p_skill: SkillDef,
	p_mods: SkillModifiers,
	p_point: Vector3,
	p_target: Node3D = null
) -> SkillCast:
	user = p_user
	player = p_user.player
	skill = p_skill
	mods = p_mods
	target_point = p_point
	target = p_target
	return self


## true: die Figur ist gesperrt (Zustand CASTING). false: läuft nebenher.
func locks_player() -> bool:
	return true


## Kanalisierte Skills zahlen laufend statt beim Start.
func is_channeled() -> bool:
	return skill.targeting == Enums.Targeting.CHANNEL


func start() -> void:
	pass


func physics(_delta: float) -> void:
	pass


## Treffermoment aus der Animation (Signal hit_frame des Modells).
func on_hit_frame() -> void:
	pass


## Taste losgelassen (kanalisierte Skills beenden sich hier).
func release() -> void:
	pass


## Abbruch von außen (Rolle, Betäubung, Tod).
func cancel() -> void:
	if finished:
		return
	finished = true
	_cleanup()


func finish() -> void:
	if finished:
		return
	finished = true
	_cleanup()


## Räumt auf, was der Einsatz an der Figur verändert hat. Unterklassen überschreiben.
func _cleanup() -> void:
	pass


# --- Hilfen für Unterklassen ---------------------------------------------------------------


func weapon_damage() -> float:
	return Stats.get_stat(player, Enums.Stat.DAMAGE)


## Gegner rundherum, nach Abstand sortiert.
func enemies_in_radius(center: Vector3, radius: float) -> Array[Node3D]:
	return enemies_in_arc(center, Vector3.FORWARD, radius, 360.0)


func enemies_in_arc(
	origin: Vector3, forward: Vector3, reach: float, arc_degrees: float
) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for hurtbox in MeleeQuery.find_targets(
		player.get_tree(), origin, forward, reach, arc_degrees, player.hurtbox.faction
	):
		result.append(hurtbox.entity)
	return result


## Schaden an allen Zielen: Waffenschaden × multiplier × Rang und Aspekte. Danach Leben
## stehlen, Betäuben, Brennen, Verlangsamen (Verbesserung) und Wut über SkillUser.
func hit_targets(
	targets: Array[Node3D], multiplier: float, knockback: float = 0.0, type: int = -1
) -> Array[DamageResult]:
	var damage_type: Enums.DamageType = skill.damage_type if type < 0 else type
	var damage := weapon_damage() * multiplier * mods.damage_factor
	var push := maxf(knockback, mods.knockback)
	var results: Array[DamageResult] = []
	var landed := 0
	var total := 0.0
	for entity in targets:
		var hit := HitInfo.create(player, entity, damage, damage_type)
		hit.skill = skill
		hit.knockback = push
		var result := Combat.apply_damage(hit)
		results.append(result)
		if result.evaded or result.amount <= 0.0:
			continue
		landed += 1
		total += result.amount
		_apply_on_hit(entity)
	enemies_hit += landed
	if mods.lifesteal > 0.0 and total > 0.0:
		player.health.heal(total * mods.lifesteal)
	if landed > 0:
		user.on_targets_hit(self, landed)
	return results


## Stößt Figuren von center weg (Einschläge, deren Mitte nicht beim Krieger liegt).
func push_from(center: Vector3, entities: Array[Node3D], distance: float) -> void:
	if distance <= 0.0:
		return
	for entity in entities:
		var knockback := Components.knockback(entity)
		var away := entity.global_position - center
		away.y = 0.0
		# Wer mitten im Einschlag steht, bleibt stehen.
		if knockback != null and Components.is_alive(entity) and away.length() > 0.3:
			knockback.apply(away, distance)


## Wut aus SkillDef.generate, höchstens einmal pro Einsatz.
func generate_resource() -> void:
	if _resource_generated or skill.generate <= 0.0:
		return
	_resource_generated = true
	user.fury.gain(skill.generate * mods.resource_factor)


## Dreht die Figur zum Punkt und liefert die waagerechte Richtung.
func face(point: Vector3) -> Vector3:
	var direction := flat_direction(point)
	if direction != Vector3.ZERO:
		player.facing = direction
	return player.facing


func flat_direction(point: Vector3) -> Vector3:
	if point == Vector3.INF:
		return Vector3.ZERO
	var offset := point - player.global_position
	offset.y = 0.0
	return offset.normalized() if offset.length_squared() > 0.0001 else Vector3.ZERO


## Punkt höchstens max_distance vom Spieler entfernt (auf dessen Höhe).
func clamp_point(point: Vector3, max_distance: float) -> Vector3:
	var origin := player.global_position
	if point == Vector3.INF:
		return origin + player.facing * max_distance
	var offset := point - origin
	offset.y = 0.0
	if offset.length() > max_distance:
		offset = offset.normalized() * max_distance
	return origin + offset


func play_animation(duration: float) -> float:
	return SkillFx.play(player.model, skill.animation, duration)


## Treffer-Effekt (Einschlag, Landung). Den Effekt beim Einsatz startet Vfx (AP1) selbst über
## EventBus.skill_cast; hier kommt der Schlüssel <vfx_key>_hit, zum Beispiel skill_leap_hit.
func spawn_fx(position: Vector3, radius: float, color: Color) -> void:
	var key := StringName("%s_hit" % skill.vfx_key) if skill.vfx_key != &"" else &""
	SkillFx.spawn(player.get_parent(), key, position, radius, color)


func _apply_on_hit(entity: Node3D) -> void:
	var effects := Components.status_effects(entity)
	if effects == null:
		return
	if mods.stun_duration > 0.0:
		effects.apply(
			StatusEffectDef.create(&"skill_stun", StatusEffectDef.Kind.STUN, mods.stun_duration),
			player
		)
	if mods.burn_ratio > 0.0:
		effects.apply(
			StatusEffectDef.create(
				&"skill_burn",
				StatusEffectDef.Kind.BURN,
				mods.burn_duration,
				weapon_damage() * mods.burn_ratio
			),
			player
		)
	var slow := skill.get_param(&"upgrade_slow")
	if mods.upgraded and slow > 0.0:
		effects.apply(
			StatusEffectDef.create(
				&"skill_slow",
				StatusEffectDef.Kind.SLOW,
				skill.get_param(&"upgrade_slow_duration", 2.0),
				slow
			),
			player
		)
