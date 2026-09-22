class_name Player
extends CharacterBody3D
## Spielerfigur: Laufen per Klick (Wegfindung) und WASD, Standardangriff, Ausweichrolle,
## Heiltrank, Zielauswahl unter der Maus.
##
## Steuerung (siehe project.godot):
##   Linksklick auf Boden   hinlaufen (Halten: der Maus folgen)
##   Linksklick auf Gegner  hinlaufen und zuschlagen (Halten: weiter zuschlagen)
##   W A S D                direkt laufen; Linksklick schlägt dann im Stand zur Maus
##   Leertaste              Ausweichrolle (kurz unverwundbar, durch Gegner hindurch)
##   Q                      Heiltrank
##   Linksklick auf Beute   hinlaufen und aufheben (GroundItem, AP4)
##
## Befehle für Bots, Tests und andere Pakete: move_to(), attack(), attack_direction(),
## dodge(), drink_potion(), pick_up(), stop(), revive().
##
## Ausrüstung: Equipment (AP4) hängt an der Figur; ihre Summe geht als feste Quelle
## &"equipment" in die StatsComponent ein.
##
## Modell: lädt MODEL_SCENE_PATH (AP8), sonst die Kapsel als Platzhalter. Das Modell darf
## play_action(name, speed) und set_move_speed(ratio) anbieten und das Signal hit_frame
## senden; dann kommt der Treffermoment aus der Animation statt aus dem Zeitgeber.

signal state_changed(new_state: State)
## Ein Standardangriff hat getroffen (Liste der getroffenen Figuren, kann leer sein).
signal attack_landed(targets: Array[Node3D])
signal dodged(direction: Vector3)

enum State { IDLE, MOVING, ATTACKING, DODGING, STUNNED, DEAD }

const MODEL_SCENE_PATH := "res://assets/characters/warrior.tscn"
const DEFAULT_CONFIG_PATH := "res://data/player/warrior.tres"
const GRAVITY := 25.0
const BODY_MASK := PhysicsLayers.WORLD | PhysicsLayers.ENEMY
## Beim Anlaufen auf ein Ziel: so viel näher als attack_range, damit der Schlag sicher trifft.
const APPROACH_MARGIN := 0.25
const NAV_RETARGET_INTERVAL := 0.2
## Ab diesem waagerechten Abstand hebt die Figur Beute auf (Meter).
const PICKUP_RANGE := 1.3
const EQUIPMENT_SOURCE := &"equipment"

@export var config: PlayerConfig
## Maus und Tastatur auswerten. Aus = nur Befehle (Bots, Zwischensequenzen).
@export var input_enabled: bool = true

var state: State = State.IDLE
## Blickrichtung (waagerecht, normiert).
var facing: Vector3 = Vector3.FORWARD
## Figur unter der Maus, oder null.
var hovered_target: Node3D
## Aktuelles Angriffsziel, oder null.
var attack_target: Node3D
## Beute, zu der die Figur gerade läuft, oder null.
var pickup_target: GroundItem
var model: Node3D

var _move_target: Vector3 = Vector3.ZERO
var _has_move_target: bool = false
var _nav_retarget_left: float = 0.0
var _keyboard_direction: Vector3 = Vector3.ZERO
var _attack_repeat: bool = false
var _attack_direction: Vector3 = Vector3.ZERO
var _attack_time: float = 0.0
var _attack_duration: float = 1.0
var _attack_hit_done: bool = false
var _dodge_time: float = 0.0
var _dodge_direction: Vector3 = Vector3.ZERO
var _dodge_cooldown_left: float = 0.0
var _primary_held: bool = false
var _follow_left: float = 0.0
var _model_drives_hits: bool = false

@onready var stats: StatsComponent = $Stats
@onready var health: HealthComponent = $Health
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var status_effects: StatusEffectsComponent = $StatusEffects
@onready var knockback: KnockbackComponent = $Knockback
@onready var potions: PotionBelt = $PotionBelt
@onready var inventory: Inventory = $Inventory
@onready var equipment: Equipment = $Equipment
@onready var nav_agent: NavigationAgent3D = $NavigationAgent
@onready var model_root: Node3D = $Model


func _ready() -> void:
	if config == null:
		config = load(DEFAULT_CONFIG_PATH) as PlayerConfig
	if config == null:
		config = PlayerConfig.new()
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = BODY_MASK
	if config.base_stats != null:
		stats.base_stats = config.base_stats
	health.reset_to_full()
	potions.configure(config)
	nav_agent.target_desired_distance = config.arrive_distance
	Game.player = self
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	status_effects.effect_started.connect(_on_effect_started)
	equipment.stats_changed.connect(_on_equipment_changed)
	_on_equipment_changed()
	_load_model()
	_on_health_changed(health.current, health.maximum)
	potions.refill()


func _exit_tree() -> void:
	if Game.player == self:
		Game.player = null
	if Engine.time_scale != 1.0 and not Combat.is_hit_stop_active():
		Engine.time_scale = 1.0


# --- Befehle -------------------------------------------------------------------------------


## Läuft zu einem Punkt (mit Wegfindung, wenn ein Navigationsnetz da ist).
func move_to(point: Vector3) -> void:
	if not can_act():
		return
	attack_target = null
	pickup_target = null
	_attack_repeat = false
	_set_move_target(point)


## Läuft zum Ziel und schlägt zu. repeat = weiter zuschlagen, bis das Ziel tot ist
## oder ein anderer Befehl kommt.
func attack(target: Node3D, repeat: bool = false) -> void:
	if not can_act() or not Components.is_alive(target):
		return
	attack_target = target
	pickup_target = null
	_attack_repeat = repeat
	_has_move_target = false


## Schlägt im Stand in eine Richtung (WASD-Steuerung, Schlag zur Maus).
func attack_direction(direction: Vector3) -> void:
	if not can_act() or state == State.ATTACKING:
		return
	attack_target = null
	_attack_repeat = false
	_has_move_target = false
	_start_attack(direction)


## Ausweichrolle. direction leer = WASD-Richtung, sonst zur Maus, sonst Blickrichtung.
## Liefert false während der Abklingzeit, beim Tod oder bei Betäubung.
func dodge(direction: Vector3 = Vector3.ZERO) -> bool:
	if state in [State.DEAD, State.STUNNED, State.DODGING] or _dodge_cooldown_left > 0.0:
		return false
	var dir := _flat(direction)
	if dir == Vector3.ZERO:
		dir = _keyboard_direction
	if dir == Vector3.ZERO and input_enabled:
		var mouse_point := mouse_ground_point()
		if mouse_point != Vector3.INF:
			dir = _flat(mouse_point - global_position)
	if dir == Vector3.ZERO:
		dir = facing
	_cancel_attack()
	_has_move_target = false
	_dodge_direction = dir
	_dodge_time = 0.0
	_dodge_cooldown_left = config.dodge_cooldown
	facing = dir
	health.set_invulnerable(&"dodge", true)
	collision_mask = PhysicsLayers.WORLD
	_set_state(State.DODGING)
	_play_model_action(&"dodge", 1.0)
	dodged.emit(dir)
	return true


## Läuft zur Beute und hebt sie auf, sobald sie in Reichweite ist.
func pick_up(item: GroundItem) -> void:
	if not can_act() or not is_instance_valid(item):
		return
	attack_target = null
	_attack_repeat = false
	pickup_target = item
	_set_move_target(item.global_position)


func drink_potion() -> bool:
	if state == State.DEAD:
		return false
	return potions.drink()


## Bricht Laufen und Angriffe ab.
func stop() -> void:
	_has_move_target = false
	attack_target = null
	pickup_target = null
	_attack_repeat = false
	if state == State.MOVING:
		_set_state(State.IDLE)


## Wiederbelebung mit vollem Leben (für den Spielablauf, AP9).
func revive() -> void:
	status_effects.clear()
	knockback.cancel()
	health.revive(1.0)
	potions.refill()
	_dodge_cooldown_left = 0.0
	collision_mask = BODY_MASK
	_set_state(State.IDLE)


# --- Abfragen ------------------------------------------------------------------------------


## true, wenn die Figur Befehle annimmt (nicht tot, nicht betäubt).
func can_act() -> bool:
	return state != State.DEAD and state != State.STUNNED and not status_effects.is_stunned()


func is_dead() -> bool:
	return state == State.DEAD


func get_dodge_cooldown_left() -> float:
	return _dodge_cooldown_left


func has_move_target() -> bool:
	return _has_move_target


## Punkt auf dem Boden unter der Maus, oder Vector3.INF.
func mouse_ground_point() -> Vector3:
	return screen_to_ground(get_viewport().get_mouse_position())


func screen_to_ground(screen_position: Vector2) -> Vector3:
	var rig := CameraRig.get_active()
	if rig == null or rig.camera == null:
		return Vector3.INF
	return rig.screen_to_ground(screen_position, global_position.y)


## Gegner unter einer Bildschirmposition: zuerst per Strahl auf Trefferflächen,
## sonst der nächste Gegner beim Bodenpunkt (großzügige Auswahl).
func pick_target_at_screen(screen_position: Vector2) -> Node3D:
	var rig := CameraRig.get_active()
	if rig == null or rig.camera == null:
		return null
	var camera := rig.camera
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.HURTBOX)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hurtbox_hit := hit.get("collider") as HurtboxComponent
		if (
			hurtbox_hit != null
			and hurtbox_hit.is_hostile_to(hurtbox.faction)
			and hurtbox_hit.is_alive()
		):
			return hurtbox_hit.entity
	var ground := screen_to_ground(screen_position)
	if ground == Vector3.INF:
		return null
	var nearest := MeleeQuery.nearest_hostile(
		get_tree(), ground, config.pick_radius, hurtbox.faction
	)
	return nearest.entity if nearest != null else null


## Abstand vom Spieler bis zum Rand des Ziels, ab dem der Standardangriff trifft.
func is_in_attack_range(target: Node3D) -> bool:
	return MeleeQuery.edge_distance(global_position, target) <= config.attack_range


# --- Ablauf --------------------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event.is_action_pressed(&"primary_action"):
		_primary_held = true
		_on_primary_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"primary_action"):
		_primary_held = false
		_attack_repeat = false
	elif event.is_action_pressed(&"dodge"):
		dodge()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"potion"):
		drink_potion()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_dodge_cooldown_left = maxf(_dodge_cooldown_left - delta, 0.0)
	if input_enabled:
		_update_hover()
		_read_keyboard()
		_process_held_mouse(delta)
	else:
		_keyboard_direction = Vector3.ZERO
	if state != State.DEAD and state != State.DODGING and status_effects.is_stunned():
		if state != State.STUNNED:
			_enter_stunned()
	var horizontal := Vector3.ZERO
	match state:
		State.DEAD:
			pass
		State.STUNNED:
			if not status_effects.is_stunned():
				_set_state(State.IDLE)
		State.DODGING:
			horizontal = _process_dodge(delta)
		State.ATTACKING:
			_process_attack(delta)
		_:
			horizontal = _process_movement(delta)
	horizontal += knockback.consume(delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_update_model(delta)


func _process_movement(delta: float) -> Vector3:
	var direction := Vector3.ZERO
	if _keyboard_direction != Vector3.ZERO:
		direction = _keyboard_direction
	elif attack_target != null:
		if not Components.is_alive(attack_target):
			attack_target = null
		elif is_in_attack_range(attack_target):
			_start_attack(attack_target.global_position - global_position)
			return Vector3.ZERO
		else:
			_nav_retarget_left -= delta
			if _nav_retarget_left <= 0.0 or not _has_move_target:
				_set_move_target(attack_target.global_position)
				_nav_retarget_left = NAV_RETARGET_INTERVAL
			direction = _path_direction()
	elif pickup_target != null:
		direction = _process_pickup()
	elif _has_move_target:
		direction = _path_direction()
	if direction == Vector3.ZERO:
		if attack_target == null:
			_has_move_target = false
		_set_state(State.IDLE)
		return Vector3.ZERO
	facing = _turn_towards(facing, direction, delta)
	_set_state(State.MOVING)
	return direction * stats.get_value(Enums.Stat.MOVE_SPEED)


## Läuft zur Beute; in Reichweite wird sie aufgehoben. Liefert die Laufrichtung.
func _process_pickup() -> Vector3:
	if not is_instance_valid(pickup_target) or pickup_target.is_queued_for_deletion():
		pickup_target = null
		return Vector3.ZERO
	if _flat_offset(pickup_target.global_position).length() <= PICKUP_RANGE:
		pickup_target.try_pick_up(inventory)
		pickup_target = null
		_has_move_target = false
		return Vector3.ZERO
	if not _has_move_target:
		_set_move_target(pickup_target.global_position)
	var direction := _path_direction()
	if direction == Vector3.ZERO:
		# Wegfindung endet vor der Beute (zum Beispiel am Rand des Netzes): direkt hin.
		direction = _flat(pickup_target.global_position - global_position)
	return direction


## Beute unter einer Bildschirmposition, oder null.
func pick_loot_at_screen(screen_position: Vector2) -> GroundItem:
	var rig := CameraRig.get_active()
	if rig == null or rig.camera == null:
		return null
	var camera := rig.camera
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.LOOT)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as GroundItem if not hit.is_empty() else null


## Richtung zum nächsten Wegpunkt; Vector3.ZERO, wenn das Ziel erreicht ist.
func _path_direction() -> Vector3:
	if not _has_move_target:
		return Vector3.ZERO
	var to_target := _flat_offset(_move_target)
	if to_target.length() <= config.arrive_distance:
		_has_move_target = false
		return Vector3.ZERO
	if _navigation_ready():
		if nav_agent.is_navigation_finished():
			_has_move_target = false
			return Vector3.ZERO
		var next := nav_agent.get_next_path_position()
		var step := _flat(next - global_position)
		if step != Vector3.ZERO:
			return step
	return to_target.normalized()


func _navigation_ready() -> bool:
	var map := nav_agent.get_navigation_map()
	return (
		map.is_valid()
		and NavigationServer3D.map_get_iteration_id(map) > 0
		and not NavigationServer3D.map_get_regions(map).is_empty()
	)


func _set_move_target(point: Vector3) -> void:
	_move_target = point
	_has_move_target = true
	nav_agent.target_position = point


func _start_attack(direction: Vector3) -> void:
	var dir := _flat(direction)
	if dir != Vector3.ZERO:
		facing = dir
	_attack_direction = facing
	var attacks_per_second := maxf(stats.get_value(Enums.Stat.ATTACK_SPEED), 0.1)
	_attack_duration = 1.0 / attacks_per_second
	_attack_time = 0.0
	_attack_hit_done = false
	_set_state(State.ATTACKING)
	_play_model_action(&"attack", attacks_per_second)


func _process_attack(delta: float) -> void:
	_attack_time += delta
	if (
		not _attack_hit_done
		and not _model_drives_hits
		and _attack_time >= _attack_duration * config.attack_hit_ratio
	):
		_perform_hit()
	# Nach dem Treffer darf WASD den Rest der Bewegung abbrechen.
	if _attack_hit_done and _keyboard_direction != Vector3.ZERO:
		_finish_attack()
		return
	if _attack_time >= _attack_duration:
		if not _attack_hit_done:
			_perform_hit()
		_finish_attack()


func _finish_attack() -> void:
	if not _attack_repeat or not Components.is_alive(attack_target):
		attack_target = null
		_attack_repeat = false
	_set_state(State.IDLE)


func _cancel_attack() -> void:
	attack_target = null
	_attack_repeat = false
	if state == State.ATTACKING:
		_set_state(State.IDLE)


## Treffermoment des Standardangriffs: alle Gegner im Bogen vor der Figur.
func _perform_hit() -> void:
	_attack_hit_done = true
	var targets := MeleeQuery.find_targets(
		get_tree(),
		global_position,
		_attack_direction,
		config.attack_range,
		config.attack_arc_degrees,
		hurtbox.faction
	)
	var damage := stats.get_value(Enums.Stat.DAMAGE) * config.attack_damage_multiplier
	var results: Array[DamageResult] = []
	var hit_entities: Array[Node3D] = []
	for target_hurtbox in targets:
		var hit := HitInfo.create(self, target_hurtbox.entity, damage)
		hit.knockback = config.attack_knockback
		var result := Combat.apply_damage(hit)
		results.append(result)
		if result.amount > 0.0:
			hit_entities.append(target_hurtbox.entity)
	Combat.hit_stop_for(results)
	attack_landed.emit(hit_entities)


func _process_dodge(delta: float) -> Vector3:
	_dodge_time += delta
	if _dodge_time >= config.dodge_invulnerable_time:
		health.set_invulnerable(&"dodge", false)
	if _dodge_time >= config.dodge_duration:
		_end_dodge()
		return Vector3.ZERO
	return _dodge_direction * (config.dodge_distance / config.dodge_duration)


func _end_dodge() -> void:
	health.set_invulnerable(&"dodge", false)
	collision_mask = BODY_MASK
	_set_state(State.IDLE)


func _enter_stunned() -> void:
	if state == State.DODGING:
		_end_dodge()
	_cancel_attack()
	_has_move_target = false
	_set_state(State.STUNNED)
	_play_model_action(&"stunned", 1.0)


# --- Eingaben ------------------------------------------------------------------------------


func _on_primary_pressed() -> void:
	if not can_act():
		return
	var target := hovered_target
	if target == null:
		target = pick_target_at_screen(get_viewport().get_mouse_position())
	if target != null:
		attack(target, true)
		return
	var loot := pick_loot_at_screen(get_viewport().get_mouse_position())
	if loot != null:
		pick_up(loot)
		return
	var point := mouse_ground_point()
	if point == Vector3.INF:
		return
	if _keyboard_direction != Vector3.ZERO:
		attack_direction(point - global_position)
	else:
		move_to(point)
		_follow_left = config.follow_retarget_interval


func _process_held_mouse(delta: float) -> void:
	if _primary_held and not Input.is_action_pressed(&"primary_action"):
		_primary_held = false
		_attack_repeat = false
	if not _primary_held or not can_act() or state in [State.ATTACKING, State.DODGING]:
		return
	if attack_target != null and Components.is_alive(attack_target):
		_attack_repeat = true
		return
	if pickup_target != null:
		return
	_follow_left -= delta
	if _follow_left > 0.0:
		return
	_follow_left = config.follow_retarget_interval
	if hovered_target != null:
		attack(hovered_target, true)
	elif _keyboard_direction == Vector3.ZERO:
		var point := mouse_ground_point()
		if point != Vector3.INF and _flat_offset(point).length() > config.arrive_distance * 2.0:
			move_to(point)


func _read_keyboard() -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if input == Vector2.ZERO:
		_keyboard_direction = Vector3.ZERO
		return
	# Bildschirm-oben = Blickrichtung der Kamera auf dem Boden.
	var yaw := 0.0
	var rig := CameraRig.get_active()
	if rig != null:
		yaw = deg_to_rad(rig.yaw_degrees)
	var basis := Basis(Vector3.UP, yaw)
	var screen_forward := basis * Vector3.FORWARD
	var screen_right := basis * Vector3.RIGHT
	_keyboard_direction = (screen_right * input.x - screen_forward * input.y).normalized()
	if state == State.MOVING or state == State.IDLE:
		_has_move_target = false
		attack_target = null
		_attack_repeat = false


func _update_hover() -> void:
	var target := pick_target_at_screen(get_viewport().get_mouse_position())
	if target != hovered_target:
		hovered_target = target
		EventBus.hovered_target_changed.emit(target)


# --- Modell --------------------------------------------------------------------------------


func _load_model() -> void:
	var placeholder := model_root.get_node_or_null("Placeholder") as Node3D
	model = placeholder
	if not ResourceLoader.exists(MODEL_SCENE_PATH):
		return
	var scene := load(MODEL_SCENE_PATH) as PackedScene
	if scene == null:
		push_warning("Player: %s ist keine Szene, nutze Platzhalter." % MODEL_SCENE_PATH)
		return
	model = scene.instantiate() as Node3D
	if model == null:
		model = placeholder
		return
	model_root.add_child(model)
	if placeholder != null:
		placeholder.queue_free()
	if model.has_signal(&"hit_frame"):
		_model_drives_hits = true
		model.connect(&"hit_frame", _on_model_hit_frame)


func _update_model(_delta: float) -> void:
	model_root.rotation.y = atan2(-facing.x, -facing.z)
	if model != null and model.has_method(&"set_move_speed"):
		var speed := Vector2(velocity.x, velocity.z).length()
		var max_speed := maxf(stats.get_value(Enums.Stat.MOVE_SPEED), 0.01)
		model.call(&"set_move_speed", speed / max_speed)


func _play_model_action(action: StringName, speed: float) -> void:
	if model != null and model.has_method(&"play_action"):
		model.call(&"play_action", action, speed)


func _on_model_hit_frame() -> void:
	if state == State.ATTACKING and not _attack_hit_done:
		_perform_hit()


# --- Signale -------------------------------------------------------------------------------


func _on_health_changed(current: float, maximum: float) -> void:
	EventBus.player_health_changed.emit(current, maximum)


func _on_equipment_changed() -> void:
	stats.set_flat_source(EQUIPMENT_SOURCE, equipment.get_bonus_stats())


func _on_died(_killer: Node3D) -> void:
	_cancel_attack()
	pickup_target = null
	_has_move_target = false
	_primary_held = false
	health.set_invulnerable(&"dodge", false)
	collision_mask = BODY_MASK
	_set_state(State.DEAD)
	_play_model_action(&"death", 1.0)


func _on_effect_started(_effect_id: StringName, kind: StatusEffectDef.Kind) -> void:
	if kind == StatusEffectDef.Kind.STUN and state != State.DEAD:
		_enter_stunned()


# --- Hilfen --------------------------------------------------------------------------------


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(new_state)
	if new_state == State.IDLE or new_state == State.MOVING:
		_play_model_action(&"idle" if new_state == State.IDLE else &"run", 1.0)


func _turn_towards(current: Vector3, target: Vector3, delta: float) -> Vector3:
	var angle := current.signed_angle_to(target, Vector3.UP)
	var max_step := config.turn_speed * delta
	if absf(angle) <= max_step:
		return target
	return current.rotated(Vector3.UP, signf(angle) * max_step).normalized()


func _flat_offset(point: Vector3) -> Vector3:
	var offset := point - global_position
	offset.y = 0.0
	return offset


static func _flat(v: Vector3) -> Vector3:
	var flat := Vector3(v.x, 0.0, v.z)
	return flat.normalized() if flat.length_squared() > 0.0001 else Vector3.ZERO
