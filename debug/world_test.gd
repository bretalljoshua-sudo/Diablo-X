extends Node3D
## Testszene für AP6: Dungeon-Ebenen, Bossraum und Dorf mit Übergängen und Minikarte.
##
## Start: godot --path . -- --scene=world_test [--depth=2] [--seed=123] [--overview]
## Tasten: 0 Dorf · 1 und 2 Ebenen · 3 Bossraum · N neuer Dungeon · P Portal öffnen
##         O Übersicht · M oder Tab große Minikarte · Linksklick oder WASD laufen

const MINIMAP_SCALE := 4.0
const MINIMAP_SCALE_BIG := 9.0
const FOLLOW_DISTANCE := 18.0

var _overview: bool = false
var _big_map: bool = false

@onready var _level: Level = $Level
@onready var _info: Label = $UI/Info
@onready var _minimap: TextureRect = $UI/Minimap
@onready var _player_dot: ColorRect = $UI/Minimap/PlayerDot
## Aufhelllicht nur für die Übersicht, weil Fackeln aus der Ferne ausgeblendet werden.
@onready var _overview_light: DirectionalLight3D = $OverviewLight


func _ready() -> void:
	EventBus.level_loaded.connect(_on_level_loaded)
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	_overview = args.has("--overview")
	_level.load_depth(_depth_from_args(args))


func _process(_delta: float) -> void:
	if _level.layout == null or not is_instance_valid(_level.player):
		return
	var pixel := MinimapData.world_to_pixel(_level.layout, _level.player.global_position)
	_player_dot.position = pixel * _minimap_scale() - _player_dot.size * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"open_map"):
		_big_map = not _big_map
		_update_minimap()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_0, KEY_1, KEY_2, KEY_3:
			World.travel_to(key.physical_keycode - KEY_0)
		KEY_N:
			World.travel_to(maxi(_level.depth, 1), true)
		KEY_P:
			World.open_portal()
			_info.text += "\nPortal offen"
		KEY_O:
			_overview = not _overview
			_update_camera()


func _on_level_loaded(layout: LevelLayout) -> void:
	_info.text = (
		"%s  ·  Seed %d  ·  %d Räume  ·  %d Zellen  ·  %d Spawnpunkte  ·  %d Lichter  ·  Aufbau %d ms"
		% [
			World.depth_title(layout.depth),
			layout.seed,
			layout.rooms.size(),
			layout.cells.size(),
			layout.spawn_points.size(),
			layout.lights.size(),
			_level.last_build_msec,
		]
	)
	_minimap.texture = ImageTexture.create_from_image(MinimapData.build_image(layout))
	_update_minimap()
	_update_camera()


func _update_minimap() -> void:
	if _minimap.texture == null:
		return
	_minimap.size = _minimap.texture.get_size() * _minimap_scale()
	_minimap.position = Vector2(get_viewport().get_visible_rect().size.x - _minimap.size.x - 16, 16)


func _minimap_scale() -> float:
	return MINIMAP_SCALE_BIG if _big_map else MINIMAP_SCALE


func _update_camera() -> void:
	var rig := _level.camera_rig
	_overview_light.visible = _overview
	if _overview and _level.layout != null:
		var bounds := _level.layout.bounds
		rig.target = null
		rig.global_position = bounds.get_center() * Vector3(1, 0, 1)
		rig.distance = maxf(bounds.size.x, bounds.size.z) * 1.3
	else:
		rig.target = _level.player
		rig.distance = FOLLOW_DISTANCE


static func _depth_from_args(args: PackedStringArray) -> int:
	for arg in args:
		if arg.begins_with("--depth="):
			return clampi(arg.trim_prefix("--depth=").to_int(), 0, World.BOSS_DEPTH)
	return 1
