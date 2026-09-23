class_name BossArena
extends Node
## Bosskampf im Bossraum (Ebene 3 von AP6). Hängt in der Spielszene und reagiert auf level_loaded.
##
## Ablauf:
##   WAITING    Boss steht am Marker boss_spawn, das Gitter am Marker boss_gate ist offen.
##   FIGHTING   Spieler betritt den Bossraum: Gitter zu, boss_encounter_started (Bossbalken, AP7).
##   DEFEATED   Boss besiegt: Gitter öffnet, Belohnungstruhe am Marker boss_chest, Portal ins Dorf
##              (World.open_portal), Signal boss_defeated.
## Stirbt der Spieler im Kampf, setzt reset_encounter() alles auf WAITING zurück (Boss voll).

signal encounter_started(boss: Enemy)
signal boss_defeated(boss: Enemy)
signal encounter_reset

enum State { NONE, WAITING, FIGHTING, DEFEATED }

const DEFAULT_BOSS := "res://data/encounters/crypt_warden.tres"
const PORTAL_COLOR := Color(0.35, 0.6, 1.0)

@export var boss_def: BossDef
## Stufe des Bosses, wenn level_provider leer ist.
@export var boss_level: int = 3

## Liefert die Stufe des Bosses beim Aufbau (Spielablauf: aus der Schwierigkeitskurve).
var level_provider: Callable
var state: State = State.NONE
var boss: Enemy
var controller: BossController
var gate: BossGate
var chest: RewardChest
var layout: LevelLayout
## Dauer des laufenden oder letzten Kampfs in Sekunden.
var fight_time: float = 0.0
var attempts: int = 0

var _portal_fx: Node3D


func _ready() -> void:
	if boss_def == null:
		boss_def = load(DEFAULT_BOSS) as BossDef
	EventBus.level_loaded.connect(_on_level_loaded)
	EventBus.level_unloading.connect(_on_level_unloading)
	EventBus.entity_died.connect(_on_entity_died)


func is_boss_level(p_layout: LevelLayout) -> bool:
	return p_layout != null and p_layout.boss_room >= 0 and p_layout.markers.has(&"boss_spawn")


## Baut Boss, Gitter und Zustand für eine Bossebene auf (sonst über level_loaded automatisch).
func setup(p_layout: LevelLayout) -> void:
	clear()
	layout = p_layout
	var parent := _actors_parent()
	if parent == null:
		return
	gate = BossGate.create_for(layout)
	if gate != null:
		parent.add_child(gate)
	var level := boss_level
	if level_provider.is_valid():
		level = int(level_provider.call())
	boss = EnemyPool.instantiate_enemy()
	boss.name = "CryptWarden"
	parent.add_child(boss)
	boss.global_position = layout.markers[&"boss_spawn"]
	boss.setup(boss_def.enemy_type, level)
	controller = BossController.attach(boss, boss_def)
	_face_room_entrance()
	fight_time = 0.0
	state = State.WAITING


## Räumt den Kampf ab (Ebenenwechsel). Die Knoten selbst entfernt die Ebene.
func clear() -> void:
	if state == State.FIGHTING and is_instance_valid(boss):
		EventBus.boss_encounter_ended.emit(boss)
	state = State.NONE
	boss = null
	controller = null
	gate = null
	chest = null
	layout = null
	_portal_fx = null


func start_fight() -> void:
	if state != State.WAITING or not is_instance_valid(boss):
		return
	state = State.FIGHTING
	attempts += 1
	fight_time = 0.0
	if gate != null:
		gate.close()
	EncounterFx.shake(0.3, 0.4)
	boss.brain.notice(Game.player, 0.8)
	EventBus.boss_encounter_started.emit(boss, boss_def.display_name)
	# Bossbalken zeigt sofort das volle Leben.
	EventBus.entity_health_changed.emit(boss, boss.health.current, boss.health.maximum)
	encounter_started.emit(boss)


## Der Spieler ist gestorben: Boss zurück auf Anfang (volles Leben, Phase 1), Gitter auf.
## Feuerflächen brennen von selbst aus.
func reset_encounter() -> void:
	if state != State.FIGHTING or not is_instance_valid(boss):
		return
	EventBus.boss_encounter_ended.emit(boss)
	controller.reset()
	boss.teleport_to(layout.markers[&"boss_spawn"])
	_face_room_entrance()
	if gate != null:
		gate.open()
	state = State.WAITING
	encounter_reset.emit()


func is_player_in_boss_room() -> bool:
	var player := Game.player
	if layout == null or not is_instance_valid(player):
		return false
	return MinimapData.room_at(layout, player.global_position) == layout.boss_room


func _physics_process(delta: float) -> void:
	match state:
		State.WAITING:
			if Components.is_alive(Game.player) and _player_engaged():
				start_fight()
		State.FIGHTING:
			fight_time += delta


func _player_engaged() -> bool:
	if not is_player_in_boss_room():
		return false
	var center: Vector3 = layout.markers.get(&"boss_room_center", boss.global_position)
	var offset := Game.player.global_position - center
	return Vector2(offset.x, offset.z).length() <= boss_def.engage_radius


func _on_level_loaded(p_layout: LevelLayout) -> void:
	if is_boss_level(p_layout):
		setup(p_layout)
	else:
		clear()


func _on_level_unloading(_layout: LevelLayout) -> void:
	clear()


func _on_entity_died(entity: Node3D, _killer: Node3D) -> void:
	if entity == null:
		return
	if entity == boss and state != State.DEFEATED and state != State.NONE:
		_on_boss_died()


func _on_boss_died() -> void:
	var was_fighting := state == State.FIGHTING
	state = State.DEFEATED
	if was_fighting:
		EventBus.boss_encounter_ended.emit(boss)
	if gate != null:
		gate.open()
	EncounterFx.shake(0.6, 0.7)
	_spawn_chest()
	World.open_portal()
	_show_portal()
	boss_defeated.emit(boss)


func _spawn_chest() -> void:
	var parent := _actors_parent()
	if parent == null or layout == null:
		return
	chest = RewardChest.new()
	chest.name = "RewardChest"
	chest.table = boss_def.chest_table
	chest.rolls = boss_def.chest_rolls
	chest.item_level = boss.level if is_instance_valid(boss) else boss_level
	parent.add_child(chest)
	var point: Vector3 = layout.markers.get(&"boss_chest", boss.global_position)
	chest.global_position = point
	var towards_center: Vector3 = layout.markers.get(&"boss_room_center", point) - point
	towards_center.y = 0.0
	if towards_center.length_squared() > 0.01:
		chest.rotation.y = atan2(towards_center.x, towards_center.z)


## Leuchtender Wirbel über dem Portalsockel, solange das Portal offen ist.
func _show_portal() -> void:
	var parent := _actors_parent()
	if parent == null or layout == null or not layout.markers.has(&"portal"):
		return
	var root := Node3D.new()
	root.name = "PortalGlow"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(PORTAL_COLOR.r, PORTAL_COLOR.g, PORTAL_COLOR.b, 0.45)
	mat.emission_enabled = true
	mat.emission = PORTAL_COLOR
	mat.emission_energy_multiplier = 2.0
	var column := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.1
	mesh.bottom_radius = 1.3
	mesh.height = 3.0
	mesh.cap_top = false
	mesh.cap_bottom = false
	column.mesh = mesh
	column.material_override = mat
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	column.position.y = 1.5
	root.add_child(column)
	var light := OmniLight3D.new()
	light.light_color = PORTAL_COLOR
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.position.y = 1.5
	root.add_child(light)
	parent.add_child(root)
	root.global_position = layout.markers[&"portal"]
	var tween := root.create_tween().set_loops()
	tween.tween_property(column, "rotation:y", TAU, 3.0).from(0.0)
	_portal_fx = root


func _face_room_entrance() -> void:
	if not is_instance_valid(boss) or layout == null:
		return
	var toward: Vector3 = (
		layout.markers.get(&"boss_gate", boss.global_position) - boss.global_position
	)
	toward.y = 0.0
	if toward.length_squared() > 0.01:
		boss.facing = toward.normalized()


func _actors_parent() -> Node3D:
	var level := Level.get_active()
	if level != null and level.actors != null:
		return level.actors
	return get_parent() as Node3D
