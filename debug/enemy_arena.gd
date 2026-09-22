extends Node3D
## Testszene von AP3 (Gegner und KI). Start: --scene=enemy_arena
##
## Eine flache Arena mit Säulen und gebackener Navigation. Gegner kommen in Wellen:
##   1  Skelett-Schwarm
##   2  Bogenschützen mit Skeletten
##   3  schwerer Ghul und Kultist-Beschwörer mit Begleitern
##   4  Elite-Skelett mit Rudel
## Sind alle Wellen besiegt, ist die Arena bestanden. Rote Flächen am Boden sind Vorwarnungen:
## Wer sie rechtzeitig verlässt oder durch sie hindurchrollt, wird nicht getroffen.
##
## Oberfläche aus AP7 (Lebenskugel, Skillleiste, Lebensbalken über Gegnern). Die Skills des
## Kriegers aus AP5 liegen wie im Spiel auf Rechtsklick und 1 bis 4.
## Tasten: F5–F8 Gruppe an der Maus (Skelette, Bogenschützen, Ghul, Kultist), F9 Elite-Gegner
## mit zufälligen Eigenschaften, F10 Belastungstest mit 60 Gegnern, B Bot an/aus,
## X alle besiegen, R Arena neu starten.
## Kommandozeile: --bot (Bot spielt), --stress (60 Gegner statt Wellen), --no-waves (leere Arena).

signal wave_started(index: int)
signal arena_completed
signal arena_failed

enum Phase { COUNTDOWN, FIGHTING, COMPLETED, FAILED, FREE }

const ARENA_HALF := 22.0
const WAVE_PAUSE := 2.0
const STRESS_COUNT := 60
const SKELETON := preload("res://data/enemies/skeleton.tres")
const GHOUL := preload("res://data/enemies/ghoul.tres")
const ARCHER := preload("res://data/enemies/skeleton_archer.tres")
const CULTIST := preload("res://data/enemies/cultist.tres")
const SPAWN_SPOTS: Array[Vector3] = [
	Vector3(0, 0, -15),
	Vector3(-15, 0, -8),
	Vector3(15, 0, -8),
	Vector3(0, 0, 15),
]

var phase: Phase = Phase.COUNTDOWN
## Index der aktuellen Welle (0-basiert), -1 vor der ersten.
var wave_index: int = -1
var experience_gained: int = 0
var kills: int = 0
var waves: Array = []

var _countdown: float = WAVE_PAUSE
var _rng: RandomNumberGenerator
var _physics_ms_avg: float = 0.0

@onready var player: Player = $Player
@onready var nav_region: NavigationRegion3D = $NavRegion
@onready var director: EnemyDirector = $Director
@onready var bot: ArenaBot = $Bot
@onready var rig: CameraRig = $CameraRig
@onready var status_label: Label = $Hud/Status
@onready var banner: Label = $Hud/Banner


func _ready() -> void:
	_rng = Rng.stream(&"enemy_arena")
	_build_arena()
	nav_region.bake_navigation_mesh(false)
	rig.target = player
	rig.global_position = player.global_position
	bot.player = player
	waves = _default_waves()
	EventBus.experience_awarded.connect(_on_experience_awarded)
	EventBus.entity_died.connect(_on_entity_died)
	var args := OS.get_cmdline_user_args()
	bot.enabled = args.has("--bot")
	if args.has("--no-waves"):
		phase = Phase.FREE
	elif args.has("--stress"):
		phase = Phase.FREE
		spawn_stress.call_deferred()


func _physics_process(_delta: float) -> void:
	var ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_physics_ms_avg = lerpf(_physics_ms_avg, ms, 0.05)
	match phase:
		Phase.COUNTDOWN:
			_countdown -= _delta
			if _countdown <= 0.0:
				_start_next_wave()
		Phase.FIGHTING:
			if director.get_alive().is_empty():
				if wave_index >= waves.size() - 1:
					_complete()
				else:
					phase = Phase.COUNTDOWN
					_countdown = WAVE_PAUSE
	if player.is_dead() and phase != Phase.FAILED and phase != Phase.FREE:
		phase = Phase.FAILED
		banner.text = "Besiegt – R startet neu"
		arena_failed.emit()


func _process(_delta: float) -> void:
	status_label.text = _status_text()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F5:
			director.spawn_types(_repeat(SKELETON, 5), _spawn_point_near_mouse())
		KEY_F6:
			director.spawn_types(
				_types([ARCHER, ARCHER, SKELETON, SKELETON]), _spawn_point_near_mouse()
			)
		KEY_F7:
			director.spawn_types(_types([GHOUL, SKELETON, SKELETON]), _spawn_point_near_mouse())
		KEY_F8:
			director.spawn_types(_types([CULTIST, SKELETON]), _spawn_point_near_mouse())
		KEY_F9:
			var types := _types([SKELETON, GHOUL, ARCHER, CULTIST])
			var type := types[_rng.randi_range(0, types.size() - 1)]
			director.spawn(type, _spawn_point_near_mouse(), 1, true, _rng)
		KEY_F10:
			spawn_stress()
		KEY_B:
			bot.enabled = not bot.enabled
		KEY_X:
			kill_all()
		KEY_R:
			restart()


## Schaltet die Wellen ab (leere Arena für eigene Gegner, zum Beispiel in Tests).
func set_free_play() -> void:
	phase = Phase.FREE
	banner.text = ""


## Startet die Arena neu: Gegner weg, Spieler voll, Wellen von vorn.
func restart() -> void:
	director.clear()
	if player.is_dead():
		player.revive()
	player.health.reset_to_full()
	player.potions.refill()
	player.global_position = Vector3(0, 0, 12)
	wave_index = -1
	kills = 0
	experience_gained = 0
	phase = Phase.COUNTDOWN
	_countdown = WAVE_PAUSE
	banner.text = ""


func kill_all() -> void:
	for enemy in director.get_alive():
		var hit := HitInfo.create(player, enemy, 1.0e6)
		hit.can_crit = false
		enemy.end_shield()
		Combat.apply_damage(hit)


## 60 Gegner gleichzeitig (Belastungstest). Die Wellen ruhen solange.
func spawn_stress() -> Array[Enemy]:
	phase = Phase.FREE
	var spawned: Array[Enemy] = []
	var types := _types([SKELETON, SKELETON, SKELETON, GHOUL, ARCHER, CULTIST])
	var index := 0
	while spawned.size() < STRESS_COUNT:
		var x := -18.0 + (index % 10) * 4.0
		var z := -18.0 + floorf(index / 10.0) * 3.0
		var type := types[index % types.size()]
		spawned.append(director.spawn(type, Vector3(x, 0, z), 1, false, _rng))
		index += 1
	return spawned


## Welle für Welle: Liste von Gruppen, jede Gruppe ist [Typen, elite].
func _default_waves() -> Array:
	return [
		[[_repeat(SKELETON, 5), false]],
		[[[ARCHER, ARCHER, SKELETON, SKELETON, SKELETON], false]],
		[[[GHOUL, SKELETON, SKELETON], false], [[CULTIST, SKELETON], false]],
		[[[SKELETON, SKELETON, SKELETON, SKELETON], true]],
	]


func _start_next_wave() -> void:
	wave_index += 1
	phase = Phase.FIGHTING
	var groups: Array = waves[wave_index]
	var spots := _spots_away_from_player()
	for i in groups.size():
		var group: Array = groups[i]
		var types: Array[EnemyType] = []
		types.assign(group[0])
		var enemies := director.spawn_types(types, spots[i % spots.size()], 1, group[1], _rng)
		for enemy in enemies:
			enemy.brain.notice(player, 0.6 + _rng.randf() * 0.4, false)
	banner.text = "Welle %d von %d" % [wave_index + 1, waves.size()]
	get_tree().create_timer(1.5).timeout.connect(_clear_banner_if_wave.bind(wave_index))
	wave_started.emit(wave_index)


func _clear_banner_if_wave(index: int) -> void:
	if wave_index == index and phase == Phase.FIGHTING:
		banner.text = ""


func _complete() -> void:
	phase = Phase.COMPLETED
	banner.text = "Arena bestanden!"
	arena_completed.emit()


func _spots_away_from_player() -> Array[Vector3]:
	var spots := SPAWN_SPOTS.duplicate()
	spots.sort_custom(
		func(a: Vector3, b: Vector3) -> bool:
			return (
				a.distance_squared_to(player.global_position)
				> b.distance_squared_to(player.global_position)
			)
	)
	return spots


func _spawn_point_near_mouse() -> Vector3:
	var point := player.mouse_ground_point()
	if not is_finite(point.x) or point.distance_to(player.global_position) < 3.0:
		point = player.global_position + player.facing * 8.0
	return Vector3(
		clampf(point.x, -ARENA_HALF + 2, ARENA_HALF - 2),
		0.0,
		clampf(point.z, -ARENA_HALF + 2, ARENA_HALF - 2)
	)


static func _types(list: Array) -> Array[EnemyType]:
	var typed: Array[EnemyType] = []
	typed.assign(list)
	return typed


static func _repeat(type: EnemyType, count: int) -> Array[EnemyType]:
	var list: Array[EnemyType] = []
	for i in count:
		list.append(type)
	return list


func _on_experience_awarded(amount: int, _source: Node3D) -> void:
	experience_gained += amount


func _on_entity_died(entity: Node3D, _killer: Node3D) -> void:
	if entity is Enemy:
		kills += 1


func _status_text() -> String:
	var lines: Array[String] = []
	match phase:
		Phase.COUNTDOWN:
			lines.append("Nächste Welle in %.1f s" % maxf(_countdown, 0.0))
		Phase.FIGHTING:
			lines.append("Welle %d von %d" % [wave_index + 1, waves.size()])
		Phase.COMPLETED:
			lines.append("Arena bestanden")
		Phase.FAILED:
			lines.append("Besiegt")
		Phase.FREE:
			lines.append("Freies Spiel")
	lines.append(
		(
			"Gegner: %d   Besiegt: %d   Erfahrung: %d"
			% [director.get_alive().size(), kills, experience_gained]
		)
	)
	var h := player.health
	lines.append(
		(
			"Leben: %d / %d   Tränke: %d"
			% [ceili(h.current), roundi(h.maximum), player.potions.charges]
		)
	)
	lines.append(
		"Physik: %.2f ms pro Takt   FPS: %d" % [_physics_ms_avg, Engine.get_frames_per_second()]
	)
	lines.append("Bot: %s" % ("an" if bot.enabled else "aus"))
	return "\n".join(lines)


# --- Aufbau --------------------------------------------------------------------------------


func _build_arena() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.34, 0.31, 0.29)
	stone.roughness = 0.9
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.2, 0.19, 0.18)
	floor_mat.roughness = 0.85
	var size := ARENA_HALF * 2.0
	_add_box(Vector3(0, -0.1, 0), Vector3(size, 0.2, size), floor_mat)
	for side: float in [-1.0, 1.0]:
		_add_box(Vector3(0, 1.5, side * (ARENA_HALF + 0.5)), Vector3(size + 2, 3, 1), stone)
		_add_box(Vector3(side * (ARENA_HALF + 0.5), 1.5, 0), Vector3(1, 3, size + 2), stone)
	for pillar: Vector3 in [
		Vector3(-7, 0, -4), Vector3(7, 0, -4), Vector3(-7, 0, 5), Vector3(7, 0, 5)
	]:
		_add_box(pillar + Vector3(0, 1.5, 0), Vector3(1.4, 3, 1.4), stone)
	_add_box(Vector3(0, 0.5, -8), Vector3(6, 1.0, 1), stone)
	for torch: Vector3 in [
		Vector3(-12, 2.4, -12), Vector3(12, 2.4, -12), Vector3(-12, 2.4, 12), Vector3(12, 2.4, 12)
	]:
		var light := OmniLight3D.new()
		light.light_color = Color(1, 0.6, 0.3)
		light.light_energy = 2.5
		light.omni_range = 12.0
		light.position = torch
		$Torches.add_child(light)


func _add_box(center: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.position = center
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	nav_region.add_child(body)
