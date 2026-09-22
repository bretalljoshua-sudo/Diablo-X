class_name TrainingDummy
extends CharacterBody3D
## Trainingspuppe als Gegner-Platzhalter, bis AP3 echte Gegner baut.
## Hat Leben, Rüstung, Resistenz, Rückstoß und Statuseffekte wie ein echter Gegner.
## Mit attack_damage > 0 schlägt sie zurück: rote Vorwarnung am Boden, dann Treffer im Umkreis.
## Nach dem Tod steht sie nach respawn_time Sekunden wieder auf (0 = bleibt liegen).

signal attacked(result: DamageResult)

@export var display_name: String = "Trainingspuppe"
@export var max_life: float = 100.0
@export var armor: float = 0.0
@export var fire_resist: float = 0.0
@export var respawn_time: float = 4.0
@export_group("Gegenangriff")
## Schaden pro Schlag, 0 = passiv.
@export var attack_damage: float = 0.0
@export var attack_interval: float = 2.5
## Vorwarnzeit vor dem Treffer (Sekunden).
@export var attack_windup: float = 0.7
## Reichweite (Meter bis zum Rand der Zielfigur).
@export var attack_range: float = 1.8
## Effekt, den ein Treffer auslöst (Verlangsamung, Brennen, Betäubung), darf leer sein.
@export var attack_effect: StatusEffectDef

var _spawn_position: Vector3
var _attack_cooldown_left: float = 1.0
var _windup_left: float = -1.0
var _respawn_left: float = -1.0
var _flash_left: float = 0.0

@onready var stats: StatsComponent = $Stats
@onready var health: HealthComponent = $Health
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var status_effects: StatusEffectsComponent = $StatusEffects
@onready var knockback: KnockbackComponent = $Knockback
@onready var model: Node3D = $Model
@onready var label: Label3D = $Label
@onready var telegraph: MeshInstance3D = $Telegraph
@onready var _body_material: StandardMaterial3D = (
	($Model/Body as MeshInstance3D).get_active_material(0).duplicate() as StandardMaterial3D
)


func _ready() -> void:
	collision_layer = PhysicsLayers.ENEMY
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.PLAYER | PhysicsLayers.ENEMY
	stats.base_stats = (
		StatBlock
		. from_dict(
			{
				Enums.Stat.MAX_LIFE: max_life,
				Enums.Stat.ARMOR: armor,
				Enums.Stat.FIRE_RESIST: fire_resist,
				Enums.Stat.DAMAGE: attack_damage,
				Enums.Stat.CRIT_CHANCE: 0.0,
			}
		)
	)
	health.reset_to_full()
	($Model/Body as MeshInstance3D).material_override = _body_material
	_spawn_position = global_position
	telegraph.visible = false
	health.health_changed.connect(func(_c: float, _m: float) -> void: _update_label())
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	status_effects.effect_started.connect(func(_id: StringName, _k: int) -> void: _update_label())
	status_effects.effect_ended.connect(func(_id: StringName, _k: int) -> void: _update_label())
	_update_label()
	EventBus.entity_spawned.emit(self)


func _physics_process(delta: float) -> void:
	if health.is_dead():
		_process_respawn(delta)
		return
	_process_flash(delta)
	var push := knockback.consume(delta)
	velocity = Vector3(push.x, velocity.y, push.z)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 25.0 * delta
	move_and_slide()
	if attack_damage > 0.0:
		_process_attack(delta)


func is_dead() -> bool:
	return health.is_dead()


func _process_attack(delta: float) -> void:
	if status_effects.is_stunned():
		_windup_left = -1.0
		telegraph.visible = false
		return
	var player := Game.player
	if _windup_left >= 0.0:
		_windup_left -= delta
		if _windup_left < 0.0:
			telegraph.visible = false
			_strike()
		return
	_attack_cooldown_left -= delta
	if _attack_cooldown_left > 0.0 or not Components.is_alive(player):
		return
	if MeleeQuery.edge_distance(global_position, player) <= attack_range:
		_windup_left = attack_windup
		telegraph.visible = true
		_attack_cooldown_left = attack_interval


func _strike() -> void:
	var player := Game.player
	if not Components.is_alive(player):
		return
	if MeleeQuery.edge_distance(global_position, player) > attack_range + 0.3:
		return
	var hit := HitInfo.create(self, player, attack_damage)
	hit.knockback = 1.0
	var result := Combat.apply_damage(hit)
	if not result.evaded and attack_effect != null:
		var effects := Components.status_effects(player)
		if effects != null:
			effects.apply(attack_effect, self)
	attacked.emit(result)


func _process_respawn(delta: float) -> void:
	if _respawn_left < 0.0:
		return
	_respawn_left -= delta
	if _respawn_left < 0.0:
		global_position = _spawn_position
		model.visible = true
		model.rotation = Vector3.ZERO
		collision_layer = PhysicsLayers.ENEMY
		health.revive(1.0)
		_update_label()


func _process_flash(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	var t := clampf(_flash_left / 0.12, 0.0, 1.0)
	_body_material.emission_energy_multiplier = 4.0 * t
	model.rotation.x = -0.25 * t


func _on_damaged(_amount: float, _source: Node3D) -> void:
	_flash_left = 0.12
	_body_material.emission_enabled = true
	_body_material.emission = Color(1, 0.9, 0.8)


func _on_died(_killer: Node3D) -> void:
	_windup_left = -1.0
	telegraph.visible = false
	model.visible = false
	collision_layer = 0
	velocity = Vector3.ZERO
	knockback.cancel()
	_respawn_left = respawn_time if respawn_time > 0.0 else -1.0
	_update_label()


func _update_label() -> void:
	if health.is_dead():
		label.text = "%s\nbesiegt" % display_name
		return
	var text := "%s\n%d / %d" % [display_name, ceili(health.current), roundi(health.maximum)]
	var effects := status_effects.get_active_ids()
	if not effects.is_empty():
		text += "\n[%s]" % ", ".join(effects)
	label.text = text
