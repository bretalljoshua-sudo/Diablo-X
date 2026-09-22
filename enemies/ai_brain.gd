class_name AIBrain
extends Node
## KI eines Gegners als Zustandsautomat:
##
##   IDLE (Ruhen)       steht, schaut alle PERCEPTION_INTERVAL Sekunden nach dem Ziel
##   NOTICE (Bemerken)  hat das Ziel gesehen, dreht sich hin, kurze Reaktionszeit
##   CHASE (Verfolgen)  läuft mit Wegfindung hin (Nahkampf) oder hält Abstand (Fernkampf)
##   ATTACK (Angreifen) Vorwarnung am Boden, am Ende der Treffer auf genau diese Fläche
##   RECOVER (Erholen)  steht nach dem Treffer kurz still und ist offen für Konter
##   DEAD
##
## Betäubung bricht eine laufende Vorwarnung ab. Schaden weckt ruhende Gegner sofort, und wer
## das Ziel bemerkt, weckt seine Gruppe (gleiche group_id). Die KI setzt nur desired_velocity
## und facing; bewegt wird der Körper vom Enemy.

enum State { IDLE, NOTICE, CHASE, ATTACK, RECOVER, DEAD }

const PERCEPTION_INTERVAL := 0.25
## Entscheidungen beim Verfolgen (Angriff wählen, Richtung) fallen 20-mal pro Sekunde, nicht in
## jedem Physik-Takt; Zeitgeber der Angriffe laufen trotzdem taktgenau.
const THINK_INTERVAL := 0.05
const REPATH_INTERVAL := 0.4
const GROUP_ALERT_RANGE := 18.0
const DIRECT_CHASE_RANGE := 2.5
const WAYPOINT_REACHED := 0.35
const TURN_SPEED := 10.0
const SEPARATION_RANGE := 1.3
const SEPARATION_STRENGTH := 1.6
## So lange steigen beschworene Diener aus dem Boden, bevor sie handeln.
const SUMMON_RISE_TIME := 0.8
## Höhe, aus der Geschosse starten und Sichtlinien geprüft werden.
const EYE_HEIGHT := 1.2

static var _instance_counter: int = 0
## Positionen aller Gegner, einmal pro Physik-Takt gesammelt (für das Auseinanderhalten).
static var _crowd_frame: int = -1
static var _crowd: PackedVector3Array = []

var state: State = State.IDLE
var target: Node3D
## Gewünschte Geschwindigkeit für diesen Physik-Takt (waagerecht).
var desired_velocity: Vector3 = Vector3.ZERO
## Laufender Angriff (nur in ATTACK und RECOVER).
var current_attack: EnemyAttack

var _enemy: Enemy
## Zwischengespeichert, weil die Suche nach Komponenten in jedem Takt zu teuer wäre.
var _target_health: HealthComponent
var _target_radius: float = 0.0
var _rng: RandomNumberGenerator
var _state_time: float = 0.0
var _timer: float = 0.0
var _perception_left: float = 0.0
## Zeitpunkt (auf _clock), ab dem ein Angriff wieder bereit ist.
var _ready_at: Dictionary[EnemyAttack, float] = {}
var _clock: float = 0.0
var _think_left: float = 0.0
var _look_direction: Vector3 = Vector3.ZERO
var _path: PackedVector3Array = []
var _path_index: int = 0
var _path_goal: Vector3 = Vector3.INF
var _repath_left: float = 0.0
var _separation: Vector3 = Vector3.ZERO
var _aim_point: Vector3 = Vector3.ZERO
var _summon_spots: Array[Vector3] = []
var _summon_telegraphs: Array[AttackTelegraph] = []
var _summons: Array[Enemy] = []
var _has_line_of_sight: bool = true


func _ready() -> void:
	_enemy = get_parent() as Enemy
	_instance_counter += 1
	_rng = Rng.stream(&"enemy_ai", _instance_counter)
	set_physics_process(false)


## Setzt die KI auf Ruhen zurück (neuer Gegner oder Wiederverwendung aus dem Pool).
func reset() -> void:
	_set_target(null)
	current_attack = null
	desired_velocity = Vector3.ZERO
	_ready_at.clear()
	_look_direction = Vector3.ZERO
	_summons.clear()
	_hide_summon_telegraphs()
	clear_path()
	# Verteilt die Wahrnehmung der Gegner über mehrere Takte.
	_perception_left = _rng.randf() * PERCEPTION_INTERVAL
	_think_left = _rng.randf() * THINK_INTERVAL
	_set_state(State.IDLE)


func clear_path() -> void:
	_path = PackedVector3Array()
	_path_index = 0
	_path_goal = Vector3.INF
	_repath_left = 0.0


## Bemerkt ein Ziel (von außen: Gruppe, Treffer, Testszenen). delay = Reaktionszeit.
func notice(new_target: Node3D, delay: float = -1.0, alert_group: bool = true) -> void:
	if state == State.DEAD or not Components.is_alive(new_target):
		return
	_set_target(new_target)
	if state != State.IDLE:
		return
	_timer = _enemy.type.notice_time if delay < 0.0 else delay
	_set_state(State.NOTICE)
	if alert_group:
		_alert_group()


func on_damaged(source: Node3D) -> void:
	if state == State.IDLE:
		var attacker := source if Components.is_alive(source) else Game.player
		notice(attacker, 0.1)


func on_stunned() -> void:
	if state == State.ATTACK:
		_cancel_attack()
		_timer = 0.2
		_set_state(State.RECOVER)


func on_died() -> void:
	_cancel_attack()
	desired_velocity = Vector3.ZERO
	_set_state(State.DEAD)


## Restliche Abklingzeit eines Angriffs.
func get_cooldown(attack: EnemyAttack) -> float:
	return maxf(_ready_at.get(attack, 0.0) - _clock, 0.0)


## Anzahl lebender eigener Diener (Beschwörer).
func get_summon_count() -> int:
	_prune_summons()
	return _summons.size()


func get_summons() -> Array[Enemy]:
	_prune_summons()
	return _summons.duplicate()


func get_state_time() -> float:
	return _state_time


func tick(delta: float) -> void:
	_clock += delta
	_state_time += delta
	if state == State.DEAD:
		desired_velocity = Vector3.ZERO
		return
	if _enemy.status_effects.is_stunned():
		desired_velocity = Vector3.ZERO
		if state == State.ATTACK:
			on_stunned()
		return
	match state:
		State.IDLE:
			desired_velocity = Vector3.ZERO
			_tick_idle(delta)
		State.NOTICE:
			desired_velocity = Vector3.ZERO
			_tick_notice(delta)
		State.CHASE:
			_think_left -= delta
			if _think_left <= 0.0:
				_think_left += THINK_INTERVAL
				_think_chase(THINK_INTERVAL)
		State.ATTACK:
			desired_velocity = Vector3.ZERO
			_tick_attack(delta)
		State.RECOVER:
			desired_velocity = Vector3.ZERO
			_tick_recover(delta)
	_turn(delta)


# --- Zustände ------------------------------------------------------------------------------


func _tick_idle(delta: float) -> void:
	_perception_left -= delta
	if _perception_left > 0.0:
		return
	_perception_left = PERCEPTION_INTERVAL
	var candidate := Game.player
	if not Components.is_alive(candidate):
		return
	var distance := _flat_distance(candidate.global_position)
	if distance <= _enemy.type.aggro_range and _line_of_sight(candidate):
		notice(candidate)


func _tick_notice(delta: float) -> void:
	if not _target_valid():
		_give_up()
		return
	_look_at(target.global_position - _enemy.global_position)
	_timer -= delta
	if _timer <= 0.0:
		_set_state(State.CHASE)


func _think_chase(delta: float) -> void:
	if not _target_valid():
		_give_up()
		return
	var to_target := target.global_position - _enemy.global_position
	var distance := Vector2(to_target.x, to_target.z).length()
	if distance > _enemy.type.lose_range:
		_give_up()
		return
	_perception_left -= delta
	if _perception_left <= 0.0:
		_perception_left = PERCEPTION_INTERVAL
		_has_line_of_sight = _line_of_sight(target)
		_update_separation()
	var edge := distance - _target_radius
	var attack := _pick_attack(edge)
	if attack != null:
		_start_attack(attack)
		return
	var direction := _chase_direction(distance, edge, delta)
	if direction != Vector3.ZERO:
		var speed := _enemy.stats.get_value(Enums.Stat.MOVE_SPEED)
		desired_velocity = (direction + _separation).normalized() * speed
		_look_at(direction)
	else:
		desired_velocity = _separation * 0.5
		_look_at(to_target)


func _tick_attack(delta: float) -> void:
	_timer -= delta
	if current_attack.kind == EnemyAttack.Kind.PROJECTILE:
		_update_aim()
	if _timer <= 0.0:
		_strike()
		_timer = current_attack.recovery / _enemy.attack_speed_multiplier
		_set_state(State.RECOVER)


func _tick_recover(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		current_attack = null
		if _target_valid():
			_think_left = 0.0
			_set_state(State.CHASE)
		else:
			_give_up()


# --- Bewegung ------------------------------------------------------------------------------


## Laufrichtung je nach Verhalten; Vector3.ZERO = stehen bleiben.
func _chase_direction(distance: float, edge: float, delta: float) -> Vector3:
	var type := _enemy.type
	if type.is_ranged():
		var too_close := type.keep_distance_min
		if type.behavior == &"summoner":
			too_close = maxf(too_close, type.flee_distance)
		if distance < too_close:
			return _retreat_direction()
		if distance > type.keep_distance_max or not _has_line_of_sight:
			return _move_towards(target.global_position, delta)
		return Vector3.ZERO
	if edge <= _melee_stop_distance():
		return Vector3.ZERO
	return _move_towards(target.global_position, delta)


## Nahkämpfer bleiben knapp innerhalb der Reichweite ihres kürzesten Angriffs stehen.
func _melee_stop_distance() -> float:
	var best := INF
	for attack in _enemy.type.attacks:
		best = minf(best, attack.max_range)
	return 1.2 if best == INF else best * 0.8


func _move_towards(point: Vector3, delta: float) -> Vector3:
	var offset := point - _enemy.global_position
	offset.y = 0.0
	if offset.length() <= DIRECT_CHASE_RANGE or not _navigation_ready():
		return offset.normalized()
	_repath_left -= delta
	if _repath_left <= 0.0 or _path_goal.distance_to(point) > 1.5 or _path.is_empty():
		_repath_left = REPATH_INTERVAL + _rng.randf() * 0.15
		var map := _enemy.get_world_3d().navigation_map
		_path = NavigationServer3D.map_get_path(map, _enemy.global_position, point, true)
		_path_index = 1
		_path_goal = point
	while _path_index < _path.size():
		var step := _path[_path_index] - _enemy.global_position
		step.y = 0.0
		if step.length() > WAYPOINT_REACHED:
			return step.normalized()
		_path_index += 1
	return offset.normalized()


func _retreat_direction() -> Vector3:
	var away := _enemy.global_position - target.global_position
	away.y = 0.0
	if away.length_squared() < 0.001:
		away = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
	away = away.normalized()
	if _navigation_ready():
		# Nicht in Wände fliehen: seitlich ausweichen, wenn hinten kein Netz mehr ist.
		var map := _enemy.get_world_3d().navigation_map
		for angle: float in [0.0, 0.7, -0.7, 1.4, -1.4]:
			var dir := away.rotated(Vector3.UP, angle)
			var probe := _enemy.global_position + dir * 2.0
			var closest := NavigationServer3D.map_get_closest_point(map, probe)
			if Vector2(closest.x - probe.x, closest.z - probe.z).length() < 0.3:
				return dir
		return Vector3.ZERO
	return away


func _update_separation() -> void:
	_separation = Vector3.ZERO
	var own := _enemy.global_position
	for other in _crowd_positions():
		var offset := own - other
		offset.y = 0.0
		var d := offset.length()
		if d < SEPARATION_RANGE and d > 0.001:
			_separation += offset / d * (1.0 - d / SEPARATION_RANGE)
	_separation = _separation.limit_length(1.0) * SEPARATION_STRENGTH


func _crowd_positions() -> PackedVector3Array:
	var frame := Engine.get_physics_frames()
	if frame != _crowd_frame:
		_crowd_frame = frame
		_crowd.clear()
		for node in _enemy.get_tree().get_nodes_in_group(Enemy.GROUP):
			var other := node as Enemy
			if other != null and other.collision_layer != 0:
				_crowd.append(other.global_position)
	return _crowd


func _navigation_ready() -> bool:
	var map := _enemy.get_world_3d().navigation_map
	return map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0


## Merkt sich die Blickrichtung; _turn() dreht in jedem Takt ein Stück dorthin.
func _look_at(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() > 0.0001:
		_look_direction = flat.normalized()


func _turn(delta: float) -> void:
	if state == State.ATTACK or _look_direction == Vector3.ZERO:
		return
	var flat := _look_direction
	var angle := _enemy.facing.signed_angle_to(flat, Vector3.UP)
	var max_step := TURN_SPEED * delta
	if absf(angle) <= max_step:
		_enemy.facing = flat
	else:
		_enemy.facing = _enemy.facing.rotated(Vector3.UP, signf(angle) * max_step).normalized()


# --- Angriffe ------------------------------------------------------------------------------


func _pick_attack(edge: float) -> EnemyAttack:
	for attack in _enemy.type.attacks:
		if get_cooldown(attack) > 0.0 or not attack.is_in_range(edge):
			continue
		if attack.kind == EnemyAttack.Kind.PROJECTILE and not _has_line_of_sight:
			continue
		if attack.kind == EnemyAttack.Kind.SUMMON:
			if attack.summon_type == null or get_summon_count() >= attack.summon_max_alive:
				continue
		return attack
	return null


func _start_attack(attack: EnemyAttack) -> void:
	current_attack = attack
	var speed := _enemy.attack_speed_multiplier
	_timer = attack.windup / speed
	_ready_at[attack] = _clock + attack.cooldown / speed
	var to_target := target.global_position - _enemy.global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.0001:
		_enemy.facing = to_target.normalized()
	var telegraph := _enemy.telegraph
	telegraph.position = Vector3(0, AttackTelegraph.HEIGHT, 0)
	telegraph.rotation = Vector3(0, atan2(-_enemy.facing.x, -_enemy.facing.z), 0)
	var color := _telegraph_color()
	match attack.kind:
		EnemyAttack.Kind.MELEE:
			telegraph.show_cone(attack.radius, attack.arc_degrees, _timer, color)
		EnemyAttack.Kind.SLAM:
			telegraph.position += _enemy.facing * attack.forward_offset
			telegraph.show_circle(attack.radius, _timer, color)
		EnemyAttack.Kind.PROJECTILE:
			_aim_point = target.global_position
			telegraph.show_line(
				attack.projectile_range, attack.projectile_radius * 2.0 + 0.5, _timer, color
			)
		EnemyAttack.Kind.SUMMON:
			_prepare_summon(attack, _timer, color)
	_set_state(State.ATTACK)
	_enemy.play_attack(attack.animation, _timer)


func _update_aim() -> void:
	if _timer <= current_attack.aim_lock_before / _enemy.attack_speed_multiplier:
		return
	if not _target_valid():
		return
	_aim_point = target.global_position
	var dir := _aim_point - _enemy.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	_enemy.facing = dir.normalized()
	_enemy.telegraph.rotation.y = atan2(-_enemy.facing.x, -_enemy.facing.z)


func _strike() -> void:
	var attack := current_attack
	_enemy.telegraph.hide_telegraph()
	match attack.kind:
		EnemyAttack.Kind.MELEE:
			for hurtbox in MeleeQuery.find_targets(
				_enemy.get_tree(),
				_enemy.global_position,
				_enemy.facing,
				attack.radius,
				attack.arc_degrees,
				Enums.Faction.ENEMY
			):
				_deal_damage(hurtbox.entity, attack)
		EnemyAttack.Kind.SLAM:
			var center := _enemy.global_position + _enemy.facing * attack.forward_offset
			for hurtbox in MeleeQuery.find_targets(
				_enemy.get_tree(), center, _enemy.facing, attack.radius, 360.0, Enums.Faction.ENEMY
			):
				_deal_damage(hurtbox.entity, attack)
			var rig := CameraRig.get_active()
			if rig != null and attack.knockback > 0.0:
				rig.shake(0.25, 0.2)
		EnemyAttack.Kind.PROJECTILE:
			var origin := _enemy.global_position + Vector3(0, EYE_HEIGHT, 0)
			EnemyProjectile.spawn(
				_projectile_parent(),
				_enemy,
				origin,
				_enemy.facing,
				attack,
				_enemy.attack_damage(attack.damage_factor),
				_hit_effect(attack)
			)
		EnemyAttack.Kind.SUMMON:
			_summon(attack)


func _deal_damage(victim: Node3D, attack: EnemyAttack) -> DamageResult:
	var hit := HitInfo.create(
		_enemy, victim, _enemy.attack_damage(attack.damage_factor), attack.damage_type
	)
	hit.knockback = attack.knockback
	var result := Combat.apply_damage(hit)
	var effect := _hit_effect(attack)
	if effect != null and not result.evaded:
		var effects := Components.status_effects(victim)
		if effects != null:
			effects.apply(effect, _enemy)
	return result


## Effekt eines Treffers: der des Angriffs, sonst der einer Elite-Eigenschaft (Brennend).
func _hit_effect(attack: EnemyAttack) -> StatusEffectDef:
	if attack.effect != null:
		return attack.effect
	return _enemy.elite.get_on_hit_effect()


func _cancel_attack() -> void:
	if _enemy != null and _enemy.telegraph != null:
		_enemy.telegraph.hide_telegraph()
	_hide_summon_telegraphs()
	current_attack = null


func _telegraph_color() -> Color:
	if _enemy.is_elite and _enemy.elite.has_kind(EliteAffix.Kind.BURNING):
		return FirePatch.FIRE_COLOR
	return AttackTelegraph.DEFAULT_COLOR


func _projectile_parent() -> Node:
	var parent := _enemy.get_parent()
	return parent if parent != null else _enemy.get_tree().current_scene


# --- Beschwören ----------------------------------------------------------------------------


func _prepare_summon(attack: EnemyAttack, time: float, color: Color) -> void:
	_summon_spots.clear()
	var count := mini(attack.summon_count, attack.summon_max_alive - get_summon_count())
	var base_angle := _rng.randf() * TAU
	for i in count:
		var angle := base_angle + TAU * i / maxf(count, 1)
		var spot := (
			_enemy.global_position + Vector3(cos(angle), 0, sin(angle)) * attack.summon_distance
		)
		spot = _snap_to_navigation(spot)
		_summon_spots.append(spot)
		var telegraph := _summon_telegraph(i)
		telegraph.global_position = spot + Vector3(0, AttackTelegraph.HEIGHT, 0)
		telegraph.show_circle(
			0.8, time, Color(0.6, 0.2, 0.9) if color == AttackTelegraph.DEFAULT_COLOR else color
		)


func _summon(attack: EnemyAttack) -> void:
	_hide_summon_telegraphs()
	var summon_type := attack.summon_type as EnemyType
	if summon_type == null:
		return
	var parent := _enemy.get_parent()
	for spot in _summon_spots:
		if get_summon_count() >= attack.summon_max_alive:
			break
		var minion: Enemy
		if _enemy.pool != null:
			minion = _enemy.pool.acquire(summon_type, parent, spot, _enemy.level, [], true)
		else:
			minion = EnemyPool.instantiate_enemy()
			minion.position = spot
			parent.add_child(minion)
			minion.setup(summon_type, _enemy.level, [], true)
		minion.summoner = _enemy
		minion.group_id = _enemy.group_id
		_summons.append(minion)
		minion.play_spawn(SUMMON_RISE_TIME)
		if _target_valid():
			minion.brain.notice(target, SUMMON_RISE_TIME, false)
	_summon_spots.clear()


func _summon_telegraph(index: int) -> AttackTelegraph:
	while _summon_telegraphs.size() <= index:
		var telegraph := AttackTelegraph.new()
		telegraph.top_level = true
		_enemy.add_child(telegraph)
		_summon_telegraphs.append(telegraph)
	return _summon_telegraphs[index]


func _hide_summon_telegraphs() -> void:
	for telegraph in _summon_telegraphs:
		telegraph.hide_telegraph()


func _prune_summons() -> void:
	var alive: Array[Enemy] = []
	for minion in _summons:
		if is_instance_valid(minion) and minion.summoner == _enemy and minion.is_active():
			alive.append(minion)
	_summons = alive


func _snap_to_navigation(point: Vector3) -> Vector3:
	if not _navigation_ready():
		return point
	var closest := NavigationServer3D.map_get_closest_point(
		_enemy.get_world_3d().navigation_map, point
	)
	return Vector3(closest.x, point.y, closest.z)


# --- Hilfen --------------------------------------------------------------------------------


func _target_valid() -> bool:
	return (
		target != null
		and is_instance_valid(target)
		and target.is_inside_tree()
		and (_target_health == null or not _target_health.is_dead())
	)


func _set_target(new_target: Node3D) -> void:
	target = new_target
	_target_health = Components.health(new_target) if new_target != null else null
	var hurtbox := Components.hurtbox(new_target) if new_target != null else null
	_target_radius = hurtbox.radius if hurtbox != null else 0.0


func _give_up() -> void:
	_set_target(null)
	_cancel_attack()
	clear_path()
	_set_state(State.IDLE)


func _alert_group() -> void:
	if _enemy.group_id == 0:
		return
	for node in _enemy.get_tree().get_nodes_in_group(Enemy.GROUP):
		var other := node as Enemy
		if other == null or other == _enemy or other.group_id != _enemy.group_id:
			continue
		if other.is_active() and other.brain.state == State.IDLE:
			if _flat_distance(other.global_position) <= GROUP_ALERT_RANGE:
				other.brain.notice(target, other.type.notice_time + _rng.randf() * 0.3, false)


func _line_of_sight(other: Node3D) -> bool:
	var from := _enemy.global_position + Vector3(0, EYE_HEIGHT, 0)
	var to := other.global_position + Vector3(0, EYE_HEIGHT, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD)
	return _enemy.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _flat_distance(point: Vector3) -> float:
	var offset := point - _enemy.global_position
	return Vector2(offset.x, offset.z).length()


func _set_state(new_state: State) -> void:
	if state == new_state and _state_time > 0.0:
		return
	state = new_state
	_state_time = 0.0
	if _enemy != null:
		_enemy.state_changed.emit(new_state)
		match new_state:
			State.IDLE, State.NOTICE, State.RECOVER:
				_enemy.play_action(&"idle", 1.0)
			State.CHASE:
				_enemy.play_action(&"run", 1.0)
