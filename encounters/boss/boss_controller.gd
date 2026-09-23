class_name BossController
extends Node
## Macht aus einem Gegner (AP3, Enemy) einen Boss mit zwei Phasen. Hängt als Kind am Enemy.
##
## Phase 1: die Angriffe des Gegnertyps aus BossDef.enemy_type.
## Phase 2 (Leben unter BossDef.phase_two_threshold): kurzes Brüllen (unverwundbar, Kamera wackelt),
## danach zusätzliche Angriffe (Beschwören) mit höherem Tempo und Feuerwellen unter dem Spieler.
## Sendet EventBus.boss_phase_changed(boss, phase) bei jedem Wechsel, auch beim Zurücksetzen.
##
## Die KI bleibt die von AP3: Phase 2 tauscht nur den Gegnertyp gegen eine Kopie mit mehr Angriffen.
## Die Angriffe selbst sind dieselben Objekte, Abklingzeiten laufen also über den Wechsel weiter.

signal phase_changed(phase: int)

const NODE_NAME := &"BossController"
const PHASE_REASON := &"boss_phase_change"
const STUN_ID := &"stun"

var def: BossDef
var enemy: Enemy
var phase: int = 1
## Zähler der Feuerwellen (für Tests und Zufall).
var fire_waves: int = 0

var _phase_two_type: EnemyType
var _roar_left: float = 0.0
var _fire_left: float = 0.0
var _stun_left: float = -1.0
var _rng: RandomNumberGenerator


## Macht enemy zum Boss. enemy muss schon eingerichtet sein (Enemy.setup mit def.enemy_type).
static func attach(p_enemy: Enemy, p_def: BossDef) -> BossController:
	var controller := BossController.new()
	controller.name = NODE_NAME
	controller.def = p_def
	p_enemy.add_child(controller)
	return controller


static func find_on(node: Node) -> BossController:
	if node == null or not is_instance_valid(node):
		return null
	return node.get_node_or_null(NodePath(NODE_NAME)) as BossController


func _ready() -> void:
	enemy = get_parent() as Enemy
	_rng = Rng.stream(&"boss", enemy.get_instance_id())
	_phase_two_type = build_phase_two_type(def)
	enemy.display_name = def.display_name
	enemy.health.health_changed.connect(_on_health_changed)
	enemy.health.died.connect(_on_died)
	enemy.status_effects.effect_started.connect(_on_effect_started)


## Kopie des Gegnertyps mit den Angriffen aus Phase 2 vorne (die KI nimmt den ersten bereiten).
static func build_phase_two_type(p_def: BossDef) -> EnemyType:
	var type := p_def.enemy_type.duplicate() as EnemyType
	var attacks: Array[EnemyAttack] = []
	attacks.append_array(p_def.phase_two_attacks)
	attacks.append_array(p_def.enemy_type.attacks)
	type.attacks = attacks
	return type


func is_roaring() -> bool:
	return _roar_left > 0.0


## Zurück auf Phase 1 mit vollem Leben (der Spieler ist gestorben, der Kampf beginnt neu).
func reset() -> void:
	_end_roar()
	phase = 1
	fire_waves = 0
	_fire_left = 0.0
	_stun_left = -1.0
	enemy.type = def.enemy_type
	enemy.attack_speed_multiplier = 1.0
	enemy.status_effects.clear()
	enemy.health.revive(1.0)
	enemy.brain.reset()
	enemy.telegraph.hide_telegraph()
	enemy.display_name = def.display_name
	for minion in enemy.brain.get_summons():
		minion.health.take_damage(minion.health.current + 1.0, null)
	EventBus.boss_phase_changed.emit(enemy, phase)
	phase_changed.emit(phase)


## Wechselt sofort in Phase 2 (sonst über das Leben ausgelöst).
func enter_phase_two() -> void:
	if phase >= 2 or enemy.health.is_dead():
		return
	phase = 2
	enemy.type = _phase_two_type
	enemy.attack_speed_multiplier = def.phase_two_attack_speed
	_fire_left = def.fire_interval * 0.5
	_start_roar()
	EventBus.boss_phase_changed.emit(enemy, phase)
	phase_changed.emit(phase)


func _physics_process(delta: float) -> void:
	if enemy == null or enemy.health.is_dead():
		return
	if _stun_left >= 0.0:
		_stun_left -= delta
		if _stun_left < 0.0:
			enemy.status_effects.remove(STUN_ID)
	if _roar_left > 0.0:
		_roar_left -= delta
		if _roar_left <= 0.0:
			_end_roar()
		return
	if phase >= 2 and _in_combat():
		_fire_left -= delta
		if _fire_left <= 0.0:
			_fire_left = def.fire_interval
			spawn_fire_wave()


## Legt eine Welle Feuerflächen: eine unter dem Ziel, die übrigen im Kreis darum.
func spawn_fire_wave() -> void:
	var target := enemy.get_target()
	if target == null or def.fire_affix == null or enemy.get_parent() == null:
		return
	fire_waves += 1
	var damage := enemy.attack_damage(def.fire_damage_factor)
	var center := target.global_position
	var base_angle := _rng.randf() * TAU
	for i in maxi(def.fire_count, 1):
		var point := center
		if i > 0:
			var angle := base_angle + TAU * (i - 1) / maxf(def.fire_count - 1, 1)
			point += Vector3(cos(angle), 0, sin(angle)) * def.fire_spread
		point = _snap_to_navigation(point)
		point.y = enemy.global_position.y
		FirePatch.spawn(enemy.get_parent(), enemy, point, def.fire_affix, damage)


func _in_combat() -> bool:
	var state := enemy.get_state()
	return (
		state == AIBrain.State.CHASE
		or state == AIBrain.State.ATTACK
		or state == AIBrain.State.RECOVER
	)


func _start_roar() -> void:
	# Laufenden Angriff abbrechen (sonst träfe er ohne Vorwarnung), dann kurz innehalten.
	if enemy.brain.state == AIBrain.State.ATTACK:
		enemy.brain.on_stunned()
	enemy.telegraph.hide_telegraph()
	enemy.health.set_invulnerable(PHASE_REASON, true)
	enemy.set_physics_process(false)
	enemy.velocity = Vector3.ZERO
	_roar_left = def.phase_change_time
	enemy.play_action(&"cast", 1.0)
	EncounterFx.shake(0.55, 0.6)
	EncounterFx.spawn(&"slam", enemy.global_position)


func _end_roar() -> void:
	_roar_left = 0.0
	enemy.health.set_invulnerable(PHASE_REASON, false)
	if not enemy.health.is_dead():
		enemy.set_physics_process(true)


func _snap_to_navigation(point: Vector3) -> Vector3:
	var world := enemy.get_world_3d()
	if world == null:
		return point
	var map := world.navigation_map
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return point
	var closest := NavigationServer3D.map_get_closest_point(map, point)
	return Vector3(closest.x, point.y, closest.z)


func _on_health_changed(current: float, maximum: float) -> void:
	if phase == 1 and maximum > 0.0 and current > 0.0:
		if current / maximum <= def.phase_two_threshold:
			enter_phase_two()


func _on_died(_killer: Node3D) -> void:
	_end_roar()
	_stun_left = -1.0
	# Der Körper bleibt liegen und verschwindet über Enemy; physics_process läuft dafür weiter.
	enemy.set_physics_process(true)


func _on_effect_started(effect_id: StringName, kind: StatusEffectDef.Kind) -> void:
	if kind == StatusEffectDef.Kind.STUN and effect_id == STUN_ID:
		_stun_left = def.max_stun_time
