extends Node3D
## Testszene von AP1 (Grafik, Licht, Kamera): eine echte Ebene mit Licht, Nebel und Materialien,
## dazu Stand-in-Gegner aus AP8, an denen sich alle Effekte auslösen lassen.
##
## Start: godot --path . -- --scene=graphics_test [--depth=1] [--seed=7] [--showcase]
##   --depth=0 Dorf, 1 und 2 Katakomben, 3 Bossraum
##   --showcase löst nach einer Sekunde Treffer, Tod, Beute und einen Sprung aus (für Bilder)
## Tasten: F5 bis F8 Grafikstufe (Niedrig bis Ultra) · 0 bis 3 Ebene · H Treffer
##         C kritischer Treffer · K Gegner töten · L Beute fallen lassen
##         E Effekt am Mauszeiger (V wechselt ihn)
##         J Kamerawackeln · Mausrad Zoom · O Ausblenden der Wände an/aus · WASD/Linksklick laufen

const ENEMIES: PackedStringArray = [
	"skeleton_swarm", "ghoul", "skeleton_archer", "cultist_summoner", "skeleton_swarm", "ghoul"
]
const SHOWCASE_FRAME := 45

var _effect_keys: Array[StringName] = []
var _effect_index: int = 0
var _actors: Array[GraphicsDemoActor] = []
var _showcase: bool = false
var _frame: int = 0
var _rng := RandomNumberGenerator.new()

@onready var _level: Level = $Level
@onready var _info: Label = $UI/Info
@onready var _help: Label = $UI/Help


func _ready() -> void:
	_rng.seed = 7
	_effect_keys.assign(VfxLibrary.SPECS.keys())
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	_showcase = args.has("--showcase")
	EventBus.level_loaded.connect(_on_level_loaded)
	Graphics.quality_applied.connect(func(_q: int) -> void: _update_info())
	_level.load_depth(_arg_int(args, "--depth=", 1))


func _process(_delta: float) -> void:
	_frame += 1
	if _showcase and _frame == SHOWCASE_FRAME:
		showcase()
	if _frame % 15 == 0:
		_update_info()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F5, KEY_F6, KEY_F7, KEY_F8:
			Settings.quality = (key.physical_keycode - KEY_F5) as Settings.Quality
			Settings.apply()
		KEY_0, KEY_1, KEY_2, KEY_3:
			_level.load_depth(key.physical_keycode - KEY_0)
		KEY_H:
			_hit_random(false)
		KEY_C:
			_hit_random(true)
		KEY_K:
			var alive := _alive_actors()
			if not alive.is_empty():
				alive[_rng.randi_range(0, alive.size() - 1)].kill(_level.player)
		KEY_L:
			drop_loot(_level.player.global_position + Vector3(1.5, 0, 1.5))
		KEY_E:
			var point := _mouse_ground()
			Vfx.spawn(_effect_keys[_effect_index], point)
		KEY_V:
			_effect_index = (_effect_index + 1) % _effect_keys.size()
			_update_info()
		KEY_J:
			CameraRig.get_active().shake(0.5, 0.4)
		KEY_O:
			Graphics.occlusion_enabled = not Graphics.occlusion_enabled


## Löst eine Reihe Effekte auf einmal aus (für Vorher-Nachher-Bilder).
func showcase() -> void:
	var player := _level.player
	drop_loot(player.global_position + Vector3(-2.5, 0, 2.0))
	if _actors.size() >= 3:
		_actors[0].take_hit(player, 37.0, true)
		_actors[1].take_hit(player, 12.0, false, Enums.DamageType.FIRE)
		_actors[2].kill(player, 60.0)
	Vfx.spawn(&"skill_war_cry", player.global_position)


func drop_loot(at: Vector3) -> void:
	var table := Loot.get_table(&"boss")
	var rng := Rng.make(_rng.randi())
	var items := Loot.roll_drop(table, 10, rng)
	var angle := 0.0
	for item in items:
		var spot := at + Vector3(cos(angle), 0, sin(angle)) * 1.2
		angle += TAU / items.size()
		GroundItem.spawn_item(_level.actors, item, spot)
		EventBus.loot_dropped.emit(item, spot)


func _on_level_loaded(layout: LevelLayout) -> void:
	_actors.clear()
	var spot := _showcase_spot(layout)
	var player := _level.player
	if player.has_method(&"teleport"):
		player.call(&"teleport", spot)
	else:
		player.global_position = spot
	_level.camera_rig.snap_to_target()
	for i in ENEMIES.size():
		var actor := GraphicsDemoActor.new()
		actor.model_name = ENEMIES[i]
		var angle := TAU * float(i) / ENEMIES.size() + 0.3
		actor.position = spot + Vector3(cos(angle), 0, sin(angle)) * 4.0
		actor.wander_radius = 0.0 if i < 3 else 1.2
		_level.actors.add_child(actor)
		actor.look_at(spot, Vector3.UP, true)
		_actors.append(actor)
	_update_info()


## Mitte des Raums mit den meisten Lichtern (schönster Blick), im Dorf der Startpunkt.
func _showcase_spot(layout: LevelLayout) -> Vector3:
	if layout.rooms.is_empty():
		return layout.player_start
	var best := -1
	var best_count := -1
	for i in layout.rooms.size():
		var rect := layout.rooms[i]
		var count := 0
		for light in layout.lights:
			var cell := Vector2i(
				floori(light.x / layout.cell_size.x), floori(light.z / layout.cell_size.z)
			)
			if rect.grow(1).has_point(cell):
				count += 1
		if count > best_count:
			best = i
			best_count = count
	var room := layout.rooms[best]
	var center := Vector2(room.position) + Vector2(room.size) * 0.5
	return Vector3(center.x * layout.cell_size.x, 0.0, center.y * layout.cell_size.z)


func _hit_random(crit: bool) -> void:
	var alive := _alive_actors()
	if alive.is_empty():
		return
	var types := [Enums.DamageType.PHYSICAL, Enums.DamageType.PHYSICAL, Enums.DamageType.FIRE]
	var target := alive[_rng.randi_range(0, alive.size() - 1)]
	target.take_hit(
		_level.player,
		_rng.randf_range(8.0, 40.0) * (2.0 if crit else 1.0),
		crit,
		types.pick_random()
	)


func _alive_actors() -> Array[GraphicsDemoActor]:
	var alive: Array[GraphicsDemoActor] = []
	for actor in _actors:
		if is_instance_valid(actor) and not actor.dead:
			alive.append(actor)
	return alive


func _mouse_ground() -> Vector3:
	var rig := CameraRig.get_active()
	var point := rig.screen_to_ground(get_viewport().get_mouse_position())
	return point if point != Vector3.INF else _level.player.global_position


func _update_info() -> void:
	if _info == null:
		return
	var preset := Graphics.get_preset()
	_info.text = (
		"Grafikstufe: %s   ·   %d FPS   ·   %s   ·   Effekt (E): %s   ·   Schattenlichter: %d"
		% [
			preset.display_name,
			Engine.get_frames_per_second(),
			World.depth_title(_level.depth),
			_effect_keys[_effect_index],
			Graphics.count_shadow_lights(),
		]
	)


static func _arg_int(args: PackedStringArray, prefix: String, fallback: int) -> int:
	for arg in args:
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix).to_int()
	return fallback
