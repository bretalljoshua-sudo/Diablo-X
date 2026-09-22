class_name EliteAffixes
extends Node
## Wirkung der Elite-Eigenschaften eines Gegners:
##   Schnell        mehr Laufgeschwindigkeit, kürzere Vorwarnung, Erholung und Abklingzeit
##   Brennend       Treffer setzen in Brand, alle paar Sekunden eine Feuerfläche unter dem Ziel
##   Schildtragend  alle paar Sekunden ein Schild (unverwundbar) für sich und die Gruppe
##   Teleportierend springt mit kurzer Vorwarnung neben ein weit entferntes Ziel
##   Vampirisch     heilt sich um einen Teil des verursachten Schadens
## Die Zeitgeber laufen nur, solange der Gegner kämpft.

const FAST_SOURCE := &"elite:fast"
const COMBAT_RANGE := 14.0

var affixes: Array[EliteAffix] = []

var _enemy: Enemy
var _timers: Dictionary[EliteAffix, float] = {}
var _teleport_telegraph: AttackTelegraph
var _teleport_left: float = -1.0
var _teleport_point: Vector3 = Vector3.ZERO
var _listening_damage: bool = false


func _ready() -> void:
	_enemy = get_parent() as Enemy
	set_physics_process(false)


func setup(p_affixes: Array[EliteAffix]) -> void:
	clear()
	affixes = p_affixes.duplicate()
	var speed_multiplier := 1.0
	var move_bonus := 0.0
	for affix in affixes:
		# Erste Auslösung gestaffelt, damit nicht alle Eigenschaften gleichzeitig starten.
		_timers[affix] = affix.interval * 0.5
		match affix.kind:
			EliteAffix.Kind.FAST:
				move_bonus += affix.move_speed_bonus
				speed_multiplier *= maxf(affix.attack_speed_multiplier, 0.1)
			EliteAffix.Kind.VAMPIRIC:
				if not _listening_damage:
					EventBus.damage_dealt.connect(_on_damage_dealt)
					_listening_damage = true
	_enemy.attack_speed_multiplier = speed_multiplier
	if move_bonus != 0.0:
		_enemy.stats.set_percent_source(
			FAST_SOURCE, StatBlock.from_dict({Enums.Stat.MOVE_SPEED: move_bonus})
		)


func clear() -> void:
	if _listening_damage:
		EventBus.damage_dealt.disconnect(_on_damage_dealt)
		_listening_damage = false
	if _enemy != null and _enemy.stats != null:
		_enemy.stats.remove_source(FAST_SOURCE)
	_timers.clear()
	_teleport_left = -1.0
	if _teleport_telegraph != null:
		_teleport_telegraph.hide_telegraph()
	affixes.clear()


func has_kind(kind: EliteAffix.Kind) -> bool:
	return get_affix(kind) != null


func get_affix(kind: EliteAffix.Kind) -> EliteAffix:
	for affix in affixes:
		if affix.kind == kind:
			return affix
	return null


## Effekt, den Treffer dieses Gegners zusätzlich auslösen (Brennend), sonst null.
func get_on_hit_effect() -> StatusEffectDef:
	var burning := get_affix(EliteAffix.Kind.BURNING)
	return burning.on_hit_effect if burning != null else null


func is_teleporting() -> bool:
	return _teleport_left >= 0.0


func tick(delta: float) -> void:
	if affixes.is_empty():
		return
	if _teleport_left >= 0.0:
		_teleport_left -= delta
		if _teleport_left < 0.0:
			_finish_teleport()
	var state := _enemy.brain.state
	var fighting := (
		state == AIBrain.State.CHASE
		or state == AIBrain.State.ATTACK
		or state == AIBrain.State.RECOVER
	)
	var target := _enemy.get_target()
	if not fighting or not Components.is_alive(target):
		return
	var distance := _enemy.global_position.distance_to(target.global_position)
	for affix in affixes:
		if affix.interval <= 0.0:
			continue
		_timers[affix] -= delta
		if _timers[affix] > 0.0:
			continue
		if _trigger(affix, target, distance):
			_timers[affix] = affix.interval
		else:
			_timers[affix] = 0.5


## Löst eine Eigenschaft aus. false = gerade nicht möglich, bald erneut versuchen.
func _trigger(affix: EliteAffix, target: Node3D, distance: float) -> bool:
	match affix.kind:
		EliteAffix.Kind.BURNING:
			if distance > COMBAT_RANGE:
				return false
			FirePatch.spawn(
				_enemy.get_parent(),
				_enemy,
				target.global_position,
				affix,
				_enemy.attack_damage(affix.damage_factor)
			)
			return true
		EliteAffix.Kind.SHIELDING:
			_shield_group(affix)
			return true
		EliteAffix.Kind.TELEPORTING:
			if distance < affix.min_distance or _enemy.brain.state != AIBrain.State.CHASE:
				return false
			return _start_teleport(affix, target)
	return true


func _shield_group(affix: EliteAffix) -> void:
	_enemy.grant_shield(affix.duration)
	if _enemy.group_id == 0:
		return
	for node in _enemy.get_tree().get_nodes_in_group(Enemy.GROUP):
		var other := node as Enemy
		if other == null or other == _enemy or other.group_id != _enemy.group_id:
			continue
		if (
			other.is_active()
			and other.global_position.distance_to(_enemy.global_position) <= affix.radius
		):
			other.grant_shield(affix.duration)


func _start_teleport(affix: EliteAffix, target: Node3D) -> bool:
	var from_target := _enemy.global_position - target.global_position
	from_target.y = 0.0
	if from_target.length_squared() < 0.001:
		return false
	var point := target.global_position + from_target.normalized() * affix.radius
	var map := _enemy.get_world_3d().navigation_map
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		point = NavigationServer3D.map_get_closest_point(map, point)
	_teleport_point = Vector3(point.x, _enemy.global_position.y, point.z)
	_teleport_left = affix.windup
	if _teleport_telegraph == null:
		_teleport_telegraph = AttackTelegraph.new()
		_teleport_telegraph.top_level = true
		_enemy.add_child(_teleport_telegraph)
	_teleport_telegraph.global_position = _teleport_point + Vector3(0, AttackTelegraph.HEIGHT, 0)
	_teleport_telegraph.show_circle(_enemy.type.body_radius + 0.6, affix.windup, affix.color)
	return true


func _finish_teleport() -> void:
	if _teleport_telegraph != null:
		_teleport_telegraph.hide_telegraph()
	if not _enemy.is_active() or Components.is_stunned(_enemy):
		return
	_enemy.teleport_to(_teleport_point)


func _on_damage_dealt(hit: HitInfo, result: DamageResult) -> void:
	if hit.source != _enemy or result.amount <= 0.0 or not _enemy.is_active():
		return
	var vampiric := get_affix(EliteAffix.Kind.VAMPIRIC)
	if vampiric != null:
		_enemy.health.heal(result.amount * vampiric.life_steal)
