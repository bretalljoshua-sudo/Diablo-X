class_name Level
extends Node3D
## Spielwelt einer Ebene (Dorf, Dungeon-Ebene oder Bossraum), aufgebaut aus einem LevelLayout.
##
## Aufbau:
##   Level
##   ├─ CameraRig
##   ├─ WorldEnvironment, Moonlight   Stimmung je Thema (AP1 kann eigene Environments liefern)
##   ├─ Geometry                      wird bei jedem Ebenenwechsel neu gebaut
##   │   ├─ Cells, Props (GridMap)  ·  Navigation  ·  Lights  ·  Triggers
##   └─ Actors                        Spielerfigur und alles, was andere Pakete einsetzen
##
## Beim Wechsel bleibt die Spielerfigur erhalten, alle anderen Actors werden entfernt.

const GROUP := &"level"
## Optionale Environments von AP1, zum Beispiel res://graphics/environments/catacombs.tres.
const ENVIRONMENT_PATH := "res://graphics/environments/%s.tres"

## Ebene, die ohne Übergang über World.travel_to() geladen wird.
@export var start_depth: int = 1
## Baut beim Start sofort eine Ebene auf.
@export var auto_load: bool = true
## Spielerfigur (AP2). Vorrang hat Game.player. Ist beides leer, läuft eine Ersatzkapsel
## (PlaceholderWalker).
@export var player_scene: PackedScene

var layout: LevelLayout
var depth: int = -1
var player: Node3D
## Dauer des letzten Aufbaus (Generieren, GridMap, Navigation, Lichter) in Millisekunden.
var last_build_msec: int = 0

var actors: Node3D
var _geometry: Node3D
var _environment: WorldEnvironment
var _moon: DirectionalLight3D
var _portal: ExitTrigger

@onready var camera_rig: CameraRig = get_node_or_null("CameraRig") as CameraRig


static func get_active() -> Level:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP) as Level


func _ready() -> void:
	add_to_group(GROUP)
	_environment = WorldEnvironment.new()
	_environment.name = "WorldEnvironment"
	add_child(_environment)
	_moon = DirectionalLight3D.new()
	_moon.name = "Moonlight"
	_moon.rotation_degrees = Vector3(-50, -30, 0)
	_moon.light_color = Color(0.55, 0.62, 0.85)
	_moon.light_energy = 0.4
	_moon.shadow_enabled = true
	add_child(_moon)
	actors = Node3D.new()
	actors.name = "Actors"
	add_child(actors)
	if auto_load:
		var target := World.consume_pending(start_depth)
		load_depth(target.x, target.y)


## Erzeugt und baut die Ebene depth. from_depth bestimmt den Ankunftsort:
## von unten kommend steht man an der Treppe nach unten, sonst am Start.
func load_depth(new_depth: int, from_depth: int = -1) -> LevelLayout:
	var started := Time.get_ticks_msec()
	var config := World.config_for_depth(new_depth)
	var new_layout := World.generate(World.seed_for_depth(new_depth), config)
	return load_layout(new_layout, from_depth, started)


func load_layout(new_layout: LevelLayout, from_depth: int = -1, started: int = -1) -> LevelLayout:
	if started < 0:
		started = Time.get_ticks_msec()
	unload()
	layout = new_layout
	depth = layout.depth
	_geometry = Node3D.new()
	_geometry.name = "Geometry"
	add_child(_geometry)
	LevelBuilder.build(layout, _geometry)
	_add_triggers()
	_apply_environment()
	_place_player(from_depth)
	World.current_layout = layout
	World.current_depth = depth
	last_build_msec = Time.get_ticks_msec() - started
	print(
		(
			"Level: Ebene %d (%s), Seed %d, %d Räume, %d Zellen, Aufbau %d ms"
			% [
				depth,
				layout.theme,
				layout.seed,
				layout.rooms.size(),
				layout.cells.size(),
				last_build_msec
			]
		)
	)
	EventBus.level_loaded.emit(layout)
	return layout


## Baut die aktuelle Ebene ab. Die Spielerfigur bleibt.
func unload() -> void:
	if layout != null:
		EventBus.level_unloading.emit(layout)
	if _geometry != null:
		remove_child(_geometry)
		_geometry.free()
		_geometry = null
	for child in actors.get_children():
		if child != player:
			child.queue_free()
	_portal = null
	layout = null


## Ort, an dem die Spielerfigur nach einem Wechsel steht.
func arrival_point(from_depth: int) -> Vector3:
	if from_depth > depth and layout.markers.has(&"exit_arrival"):
		return layout.markers[&"exit_arrival"]
	return layout.player_start


func set_portal_active(value: bool) -> void:
	if _portal != null:
		_portal.active = value


func get_navigation_region() -> NavigationRegion3D:
	return _geometry.get_node_or_null("Navigation") as NavigationRegion3D if _geometry else null


func _add_triggers() -> void:
	var triggers := Node3D.new()
	triggers.name = "Triggers"
	_geometry.add_child(triggers)
	for exit in layout.exits:
		triggers.add_child(ExitTrigger.create(exit, depth + 1))
	if layout.entrance != Vector3.INF:
		triggers.add_child(ExitTrigger.create(layout.entrance, depth - 1))
	if layout.markers.has(&"portal"):
		_portal = ExitTrigger.create(layout.markers[&"portal"], World.VILLAGE_DEPTH)
		_portal.active = false
		triggers.add_child(_portal)


func _apply_environment() -> void:
	var theme := layout.theme if layout.theme != &"" else &"catacombs"
	var path := ENVIRONMENT_PATH % theme
	if ResourceLoader.exists(path):
		_environment.environment = load(path) as Environment
	else:
		_environment.environment = default_environment(theme)
	_moon.visible = theme == &"village"


## Einfache Stimmung je Thema, bis AP1 eigene Environments liefert.
static func default_environment(theme: StringName) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.glow_enabled = true
	env.fog_enabled = true
	match theme:
		&"village":
			env.background_color = Color(0.05, 0.06, 0.1)
			env.ambient_light_color = Color(0.4, 0.45, 0.6)
			env.ambient_light_energy = 0.55
			env.fog_light_color = Color(0.12, 0.13, 0.18)
			env.fog_density = 0.004
		&"boss":
			env.background_color = Color(0.02, 0.005, 0.005)
			env.ambient_light_color = Color(0.5, 0.25, 0.2)
			env.ambient_light_energy = 0.25
			env.fog_light_color = Color(0.15, 0.04, 0.03)
			env.fog_density = 0.01
		_:
			env.background_color = Color(0.01, 0.01, 0.015)
			env.ambient_light_color = Color(0.35, 0.38, 0.5)
			env.ambient_light_energy = 0.25
			env.fog_light_color = Color(0.06, 0.06, 0.08)
			env.fog_density = 0.008
	return env


func _place_player(from_depth: int) -> void:
	if not is_instance_valid(player):
		if is_instance_valid(Game.player):
			player = Game.player
		elif player_scene != null:
			player = player_scene.instantiate() as Node3D
		else:
			player = PlaceholderWalker.new()
		if player.get_parent() == null:
			actors.add_child(player)
		if not is_instance_valid(Game.player):
			Game.player = player
	var point := arrival_point(from_depth)
	if player.has_method(&"teleport"):
		player.call(&"teleport", point)
	else:
		player.global_position = point
		if player.has_method(&"stop"):
			player.call(&"stop")
	if camera_rig != null:
		camera_rig.target = player
		camera_rig.global_position = point
