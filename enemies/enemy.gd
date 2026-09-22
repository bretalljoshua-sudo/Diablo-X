class_name Enemy
extends CharacterBody3D
## Gegner: Körper, Komponenten aus AP2 (Stats, Health, Hurtbox, StatusEffects, Knockback),
## KI (AIBrain), Elite-Eigenschaften (EliteAffixes) und Modell.
##
## Ein Gegner entsteht über EnemyPool.acquire() (oder EnemyDirector.spawn()) und wird nach dem
## Tod an den Pool zurückgegeben. Alles, was ein Gegnertyp kann, steht in seinem EnemyType.
##
## Signale an andere Pakete (über EventBus, keine direkte Kopplung):
##   entity_spawned beim Erscheinen, entity_health_changed (HealthComponent), entity_died (Combat),
##   loot_dropped (über Loot.drop_at), experience_awarded beim Tod.
## Für Lebensbalken (AP7): display_name, is_elite, level, get_health_bar_position().
##
## Modell: lädt type.model_path (AP8, CharacterModel), sonst eine Kapsel. Genutzt wird, was das
## Modell anbietet: play_action(name, tempo), set_move_velocity(m/s) oder set_move_speed(anteil),
## get_event_time(clip, ereignis), get_action_length(clip), revive().
## Den Treffermoment bestimmt die Vorwarnung, nicht die Animation, damit sie fair bleibt: Das
## Tempo der Angriffsanimation wird so gewählt, dass ihr Trefferzeitpunkt aufs Ende fällt.

signal state_changed(new_state: AIBrain.State)
## Der Gegner geht an den Pool zurück (Körper verschwunden).
signal released

const GROUP := &"enemies"
## So lange bleibt der Körper nach dem Tod mindestens liegen (länger, wenn die Todesanimation
## länger dauert). In der letzten SINK_TIME versinkt er im Boden.
const CORPSE_TIME := 1.5
const SINK_TIME := 0.6
const HIT_REACTION_INTERVAL := 0.6
const SHIELD_REASON := &"elite_shield"
const ELITE_SOURCE := &"elite"

## Beschriftung mit Name und Leben über jedem Gegner (für Testszenen, bis AP7 Balken zeigt).
static var debug_labels: bool = false
static var _loot_counter: int = 0
static var _placeholder_cache: Dictionary[String, Resource] = {}

var type: EnemyType
var level: int = 1
var is_elite: bool = false
## Beschworene Diener lassen keine Beute fallen und geben keine Erfahrung.
var is_summon: bool = false
var affixes: Array[EliteAffix] = []
var display_name: String = ""
## Gegner mit gleicher group_id bemerken das Ziel gemeinsam (0 = keine Gruppe).
var group_id: int = 0
## Pool, zu dem der Gegner nach dem Tod zurückkehrt (null = queue_free).
var pool: EnemyPool
## Beschwörer dieses Dieners, falls beschworen.
var summoner: Enemy
## Schneller-Faktor für Vorwarnung, Erholung und Abklingzeiten (Elite „Schnell“).
var attack_speed_multiplier: float = 1.0
var facing: Vector3 = Vector3.FORWARD
var model: Node3D

var _model_type_id: StringName = &""
var _model_has_move_speed: bool = false
var _model_has_velocity: bool = false
var _model_has_action: bool = false
var _model_speed_sent: float = -1.0
var _corpse_time: float = CORPSE_TIME
var _hit_reaction_left: float = 0.0
var _floor_y: float = 0.0
var _corpse_left: float = -1.0
var _flash_left: float = 0.0
var _shield_left: float = 0.0
var _label: Label3D
var _shield_mesh: MeshInstance3D
var _elite_ring: MeshInstance3D

@onready var stats: StatsComponent = $Stats
@onready var health: HealthComponent = $Health
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var status_effects: StatusEffectsComponent = $StatusEffects
@onready var knockback: KnockbackComponent = $Knockback
@onready var brain: AIBrain = $Brain
@onready var elite: EliteAffixes = $Elite
@onready var model_root: Node3D = $Model
@onready var telegraph: AttackTelegraph = $Telegraph
@onready var body_shape: CollisionShape3D = $Collision
@onready var hurt_shape: CollisionShape3D = $Hurtbox/Shape


func _ready() -> void:
	add_to_group(GROUP)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	max_slides = 3
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	status_effects.effect_started.connect(_on_effect_started)


## Richtet den Gegner ein (auch bei Wiederverwendung aus dem Pool). Muss im Baum hängen.
func setup(
	p_type: EnemyType, p_level: int = 1, p_affixes: Array[EliteAffix] = [], p_summon: bool = false
) -> void:
	type = p_type
	level = maxi(p_level, 1)
	affixes = p_affixes.duplicate()
	is_elite = not affixes.is_empty()
	is_summon = p_summon
	summoner = null
	group_id = 0
	attack_speed_multiplier = 1.0
	_corpse_left = -1.0
	_flash_left = 0.0
	_hit_reaction_left = 0.0
	_model_speed_sent = -1.0
	_floor_y = global_position.y
	facing = Vector3.FORWARD
	velocity = Vector3.ZERO
	collision_layer = PhysicsLayers.ENEMY
	# Gegner schieben sich nicht gegenseitig (spart viel Physik), die KI hält sie auseinander.
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.PLAYER
	_apply_body()
	_load_model()
	stats.remove_source(ELITE_SOURCE)
	stats.base_stats = _base_stats()
	knockback.resistance = type.knockback_resistance
	knockback.cancel()
	status_effects.clear()
	health.revive(1.0)
	end_shield()
	elite.setup(affixes)
	display_name = _build_display_name()
	brain.reset()
	telegraph.hide_telegraph()
	model_root.visible = true
	model_root.rotation = Vector3.ZERO
	model_root.position = Vector3.ZERO
	var model_scale := type.model_scale * (EliteRules.get_default().scale if is_elite else 1.0)
	model_root.scale = Vector3.ONE * model_scale
	_update_elite_ring()
	_update_label()
	set_physics_process(true)
	visible = true
	if model.has_method(&"revive"):
		model.call(&"revive")
	_play(&"idle", 1.0)
	EventBus.entity_spawned.emit(self)


func is_dead() -> bool:
	return health.is_dead()


func is_active() -> bool:
	return type != null and is_inside_tree() and not health.is_dead()


## Weltpunkt über dem Kopf, zum Beispiel für den Lebensbalken (AP7).
func get_health_bar_position() -> Vector3:
	var height := type.body_height if type != null else 1.8
	return global_position + Vector3(0, height * model_root.scale.y + 0.35, 0)


## Aktuelles Ziel der KI (Game.player, solange es lebt), sonst null.
func get_target() -> Node3D:
	return brain.target


func get_state() -> AIBrain.State:
	return brain.state


## Schaden eines Angriffs mit dem Faktor factor (DAMAGE × factor).
func attack_damage(factor: float) -> float:
	return stats.get_value(Enums.Stat.DAMAGE) * factor


## Macht den Gegner für duration Sekunden unverwundbar (Elite „Schildtragend“).
func grant_shield(duration: float) -> void:
	if health.is_dead():
		return
	_shield_left = maxf(_shield_left, duration)
	health.set_invulnerable(SHIELD_REASON, true)
	_get_shield_mesh().visible = true


func end_shield() -> void:
	_shield_left = 0.0
	health.set_invulnerable(SHIELD_REASON, false)
	if _shield_mesh != null:
		_shield_mesh.visible = false


func has_shield() -> bool:
	return _shield_left > 0.0


## Setzt den Gegner an einen neuen Ort (Teleport), ohne die KI zurückzusetzen.
func teleport_to(point: Vector3) -> void:
	global_position = Vector3(point.x, _floor_y, point.z)
	velocity = Vector3.ZERO
	brain.clear_path()


func play_action(action: StringName, speed: float = 1.0) -> void:
	_play(action, speed)


## Spielt eine Angriffsanimation so, dass ihr Treffer- oder Abschusszeitpunkt nach windup
## Sekunden kommt (genau am Ende der Vorwarnung).
func play_attack(action: StringName, windup: float) -> void:
	if not _model_has_action:
		return
	var time := maxf(windup, 0.05)
	var speed := 1.0 / time
	if model.has_method(&"get_event_time"):
		var event_time: float = model.call(&"get_event_time", action, &"hit")
		if event_time <= 0.0:
			event_time = model.call(&"get_event_time", action, &"release")
		if event_time > 0.0:
			speed = event_time / time
		elif model.has_method(&"get_action_length"):
			speed = maxf(model.call(&"get_action_length", action), 0.1) / time
	model.call(&"play_action", action, speed)


## Aufstehen aus dem Boden (beschworene Diener), dauert duration Sekunden.
func play_spawn(duration: float) -> void:
	if not _model_has_action:
		return
	var length := 1.0
	if model.has_method(&"get_action_length"):
		length = maxf(model.call(&"get_action_length", &"spawn"), 0.1)
	model.call(&"play_action", &"spawn", length / maxf(duration, 0.05))


func _physics_process(delta: float) -> void:
	if type == null:
		return
	if health.is_dead():
		_process_corpse(delta)
		return
	if _shield_left > 0.0:
		_shield_left -= delta
		if _shield_left <= 0.0:
			end_shield()
	brain.tick(delta)
	elite.tick(delta)
	var move := brain.desired_velocity + knockback.consume(delta)
	move.y = 0.0
	velocity = move
	if move.length_squared() > 0.0001:
		move_and_slide()
		if absf(global_position.y - _floor_y) > 0.001:
			global_position.y = _floor_y
	_update_model(delta)


func _process_corpse(delta: float) -> void:
	if _corpse_left < 0.0:
		return
	_corpse_left -= delta
	if not _model_has_action:
		# Kapsel kippt um.
		model_root.rotation.x = lerpf(model_root.rotation.x, -PI * 0.5, minf(delta * 10.0, 1.0))
	if _corpse_left < SINK_TIME:
		model_root.position.y -= delta * 1.5
	if _corpse_left <= 0.0:
		_corpse_left = -1.0
		_release()


func _release() -> void:
	set_physics_process(false)
	released.emit()
	if pool != null and is_instance_valid(pool):
		pool.release.call_deferred(self)
	else:
		queue_free()


func _on_died(_killer: Node3D) -> void:
	brain.on_died()
	elite.clear()
	end_shield()
	telegraph.hide_telegraph()
	collision_layer = 0
	velocity = Vector3.ZERO
	knockback.cancel()
	_corpse_time = CORPSE_TIME
	if _model_has_action and model.has_method(&"get_action_length"):
		_corpse_time = maxf(CORPSE_TIME, model.call(&"get_action_length", &"death") + SINK_TIME)
	_corpse_left = _corpse_time
	_play(&"death", 1.0)
	_update_label()
	if not is_summon:
		_award_experience()
		_drop_loot()
	# Beschworene Diener zählen beim Beschwörer nicht mehr.
	summoner = null


func _award_experience() -> void:
	var xp := type.experience_for_level(level)
	if is_elite:
		xp = int(roundf(xp * EliteRules.get_default().experience_multiplier))
	if xp > 0:
		EventBus.experience_awarded.emit(xp, self)


func _drop_loot() -> void:
	var table := type.loot_table
	if is_elite and EliteRules.get_default().loot_table != null:
		table = EliteRules.get_default().loot_table
	if table == null or get_parent() == null:
		return
	_loot_counter += 1
	Loot.drop_at(
		table, level, Rng.stream(&"enemy_loot", _loot_counter), global_position, get_parent()
	)


func _on_damaged(_amount: float, source: Node3D) -> void:
	_flash_left = 0.12
	_update_label()
	brain.on_damaged(source)
	# Trefferreaktion nur, wenn sie keinen Angriff unterbricht.
	var state := brain.state
	if (
		_hit_reaction_left <= 0.0
		and not health.is_dead()
		and (state == AIBrain.State.CHASE or state == AIBrain.State.NOTICE)
	):
		_hit_reaction_left = HIT_REACTION_INTERVAL
		_play(&"hit", 1.0)


func _on_effect_started(_effect_id: StringName, kind: StatusEffectDef.Kind) -> void:
	if kind == StatusEffectDef.Kind.STUN:
		brain.on_stunned()
		_play(&"stunned", 1.0)


func _base_stats() -> StatBlock:
	var block := type.stats_for_level(level)
	if is_elite:
		var rules := EliteRules.get_default()
		block.set_value(
			Enums.Stat.MAX_LIFE,
			(
				block.get_value(Enums.Stat.MAX_LIFE, StatDefaults.get_default(Enums.Stat.MAX_LIFE))
				* rules.life_multiplier
			)
		)
		block.set_value(
			Enums.Stat.DAMAGE,
			(
				block.get_value(Enums.Stat.DAMAGE, StatDefaults.get_default(Enums.Stat.DAMAGE))
				* rules.damage_multiplier
			)
		)
	if not block.values.has(Enums.Stat.CRIT_CHANCE):
		block.set_value(Enums.Stat.CRIT_CHANCE, 0.0)
	return block


func _build_display_name() -> String:
	var base_name := type.display_name if type.display_name != "" else String(type.id)
	if not is_elite:
		return base_name
	var names: Array[String] = []
	for affix in affixes:
		names.append(affix.display_name)
	return "%s (%s)" % [base_name, ", ".join(names)]


# --- Körper und Modell ------------------------------------------------------------------------


func _apply_body() -> void:
	var body := body_shape.shape as CylinderShape3D
	if body == null or not body.resource_local_to_scene:
		body = CylinderShape3D.new()
		body.resource_local_to_scene = true
		body_shape.shape = body
	body.radius = type.body_radius
	body.height = type.body_height
	body_shape.position.y = type.body_height * 0.5
	var hurt := hurt_shape.shape as CylinderShape3D
	if hurt == null or not hurt.resource_local_to_scene:
		hurt = CylinderShape3D.new()
		hurt.resource_local_to_scene = true
		hurt_shape.shape = hurt
	var scale_factor := EliteRules.get_default().scale if not affixes.is_empty() else 1.0
	hurt.radius = type.body_radius * scale_factor + 0.1
	hurt.height = type.body_height * scale_factor + 0.2
	hurt_shape.position.y = hurt.height * 0.5
	hurtbox.radius = hurt.radius


func _load_model() -> void:
	if _model_type_id == type.id and model != null:
		return
	if model != null:
		model.queue_free()
		model = null
	_model_type_id = type.id
	if type.model_path != "" and ResourceLoader.exists(type.model_path):
		var scene := load(type.model_path) as PackedScene
		if scene != null:
			model = scene.instantiate() as Node3D
	if model == null:
		model = _build_placeholder()
	model_root.add_child(model)
	_model_has_move_speed = model.has_method(&"set_move_speed")
	_model_has_velocity = model.has_method(&"set_move_velocity")
	_model_has_action = model.has_method(&"play_action")


## Kapsel mit leuchtenden Augen und einer Waffe als Platzhalter, bis AP8 Modelle liefert.
func _build_placeholder() -> Node3D:
	var root := Node3D.new()
	root.name = "Placeholder"
	var body := MeshInstance3D.new()
	body.mesh = _placeholder_body_mesh()
	body.position.y = type.body_height * 0.5
	root.add_child(body)
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = _placeholder_eye_mesh()
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.position = Vector3(
			side * type.body_radius * 0.35, type.body_height * 0.82, -type.body_radius * 0.85
		)
		root.add_child(eye)
	var weapon := MeshInstance3D.new()
	weapon.mesh = _placeholder_weapon_mesh()
	weapon.position = Vector3(type.body_radius + 0.08, type.body_height * 0.55, -0.25)
	root.add_child(weapon)
	return root


func _placeholder_body_mesh() -> Mesh:
	var key := "body/%s" % type.id
	if not _placeholder_cache.has(key):
		var mesh := CapsuleMesh.new()
		mesh.radius = type.body_radius
		mesh.height = type.body_height
		var mat := StandardMaterial3D.new()
		mat.albedo_color = type.placeholder_color
		mat.roughness = 0.8
		mesh.material = mat
		_placeholder_cache[key] = mesh
	return _placeholder_cache[key] as Mesh


func _placeholder_eye_mesh() -> Mesh:
	var key := "eye"
	if not _placeholder_cache.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = 0.06
		mesh.height = 0.12
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.25, 0.1)
		mesh.material = mat
		_placeholder_cache[key] = mesh
	return _placeholder_cache[key] as Mesh


func _placeholder_weapon_mesh() -> Mesh:
	var key := "weapon/%s" % type.id
	if not _placeholder_cache.has(key):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.08, 0.08, 0.9) if not type.is_ranged() else Vector3(0.06, 1.1, 0.06)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.3, 0.25)
		mesh.material = mat
		_placeholder_cache[key] = mesh
	return _placeholder_cache[key] as Mesh


func _update_model(delta: float) -> void:
	model_root.rotation.y = atan2(-facing.x, -facing.z)
	if _hit_reaction_left > 0.0:
		_hit_reaction_left -= delta
	if _flash_left > 0.0:
		_flash_left -= delta
		var t := clampf(_flash_left / 0.12, 0.0, 1.0)
		model_root.rotation.x = -0.2 * t
	if not _model_has_velocity and not _model_has_move_speed:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	# Nur bei spürbarer Änderung weitergeben, das Setzen am AnimationTree kostet Zeit.
	if absf(speed - _model_speed_sent) < 0.1:
		return
	_model_speed_sent = speed
	if _model_has_velocity:
		model.call(&"set_move_velocity", speed)
	else:
		var max_speed := maxf(stats.get_value(Enums.Stat.MOVE_SPEED), 0.01)
		model.call(&"set_move_speed", speed / max_speed)


func _play(action: StringName, speed: float) -> void:
	if _model_has_action:
		model.call(&"play_action", action, speed)


func _update_elite_ring() -> void:
	if not is_elite:
		if _elite_ring != null:
			_elite_ring.visible = false
		return
	if _elite_ring == null:
		_elite_ring = MeshInstance3D.new()
		_elite_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.9
		mesh.outer_radius = 1.0
		mesh.rings = 24
		mesh.ring_segments = 4
		_elite_ring.mesh = mesh
		_elite_ring.position.y = 0.05
		add_child(_elite_ring)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = affixes[0].color
	_elite_ring.material_override = mat
	var r := type.body_radius * EliteRules.get_default().scale + 0.35
	_elite_ring.scale = Vector3(r, 1.0, r)
	_elite_ring.visible = true


func _get_shield_mesh() -> MeshInstance3D:
	if _shield_mesh == null:
		_shield_mesh = MeshInstance3D.new()
		_shield_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.45, 0.75, 1.0, 0.3)
		mesh.material = mat
		_shield_mesh.mesh = mesh
		add_child(_shield_mesh)
	var height := type.body_height * model_root.scale.y
	_shield_mesh.scale = Vector3(type.body_radius + 0.5, height * 0.6, type.body_radius + 0.5)
	_shield_mesh.position.y = height * 0.5
	return _shield_mesh


func _update_label() -> void:
	if not debug_labels:
		if _label != null:
			_label.visible = false
		return
	if _label == null:
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.font_size = 32
		_label.outline_size = 8
		add_child(_label)
	_label.visible = true
	_label.position.y = type.body_height * model_root.scale.y + 0.5
	_label.modulate = Color(1, 0.75, 0.2) if is_elite else Color.WHITE
	if health.is_dead():
		_label.text = display_name
		return
	_label.text = "%s\n%d / %d" % [display_name, ceili(health.current), roundi(health.maximum)]
