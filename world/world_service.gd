extends Node
## Autoload „World“ (AP6): erzeugt Ebenen und steuert die Übergänge zwischen ihnen.
##
## Vertrag: generate(p_seed: int, config: LevelConfig) -> LevelLayout
##   Gleicher Seed und gleiche config ergeben immer dasselbe Layout.
##   depth 0 ist das Dorf (feste Karte), 1 und 2 sind Dungeon-Ebenen, 3 ist der Bossraum.
##
## Übergänge: travel_to(depth) zeigt den Ladebildschirm, baut die Ebene in der aktiven
## Level-Szene neu auf (oder wechselt zu world/level.tscn) und blendet wieder ein.

const LEVEL_SCENE := "res://world/level.tscn"
const ROOMS_DIR := "res://data/world/rooms"
const LEVEL_CONFIG_PATH := "res://data/world/levels/depth_%d.tres"
const VILLAGE_PATH := "res://data/world/village.tres"
const VILLAGE_DEPTH := 0
const BOSS_DEPTH := 3

const DEPTH_TITLES: Dictionary[int, String] = {
	0: "Dorf Aschental",
	1: "Katakomben – Ebene 1",
	2: "Katakomben – Ebene 2",
	3: "Gruft des Wächters",
}

## Aktuell geladene Ebene (-1 = keine).
var current_depth: int = -1
var current_layout: LevelLayout
## Seed des aktuellen Dungeon-Durchlaufs. Jeder Gang vom Dorf in die Katakomben würfelt neu.
var run_seed: int = 0
var is_transitioning: bool = false
var loading_screen: LoadingScreen

var _templates: Array[RoomTemplate] = []
var _pending_depth: int = -1
var _pending_from: int = -1


func _ready() -> void:
	loading_screen = LoadingScreen.new()
	loading_screen.name = "LoadingScreen"
	add_child(loading_screen)


func generate(p_seed: int, config: LevelConfig) -> LevelLayout:
	if config == null:
		config = LevelConfig.new()
	if config.depth <= VILLAGE_DEPTH or config.theme == &"village":
		return VillageMap.generate(load(VILLAGE_PATH) as FixedMap, p_seed)
	return DungeonGenerator.generate_layout(p_seed, config, get_templates())


## Alle Raumvorlagen aus data/world/rooms/, nach Dateiname sortiert (für feste Reihenfolge).
func get_templates() -> Array[RoomTemplate]:
	if _templates.is_empty():
		var files := Array(ResourceLoader.list_directory(ROOMS_DIR))
		files.sort()
		for file: String in files:
			if file.ends_with(".tres") or file.ends_with(".res"):
				var template := load("%s/%s" % [ROOMS_DIR, file]) as RoomTemplate
				if template != null:
					_templates.append(template)
	return _templates


func config_for_depth(depth: int) -> LevelConfig:
	var path := LEVEL_CONFIG_PATH % depth
	if ResourceLoader.exists(path):
		return load(path) as LevelConfig
	var config := LevelConfig.new()
	config.depth = depth
	config.is_boss_level = depth >= BOSS_DEPTH
	return config


## Seed einer Ebene im aktuellen Durchlauf. Das Dorf hat immer Seed 0.
func seed_for_depth(depth: int) -> int:
	if depth <= VILLAGE_DEPTH:
		return 0
	if run_seed == 0:
		start_new_run()
	return absi(hash([run_seed, depth]))


## Neuer Dungeon-Durchlauf: alle Ebenen werden neu gewürfelt.
func start_new_run(p_seed: int = 0) -> void:
	run_seed = p_seed if p_seed != 0 else absi(Rng.next_seed(&"dungeon_run")) + 1


static func depth_title(depth: int) -> String:
	return DEPTH_TITLES.get(depth, "Ebene %d" % depth)


## Wechselt zur Ebene depth mit Ladebildschirm. new_run würfelt den Dungeon neu.
## Aus dem Dorf in die Katakomben beginnt immer ein neuer Durchlauf.
func travel_to(depth: int, new_run: bool = false) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	var from := current_depth
	if new_run or (from <= VILLAGE_DEPTH and depth > VILLAGE_DEPTH):
		start_new_run()
	EventBus.level_transition_started.emit(depth)
	loading_screen.show_screen(depth_title(depth))
	# Zwei Bilder warten, damit der Ladebildschirm sichtbar ist, bevor der Aufbau blockiert.
	await get_tree().process_frame
	await get_tree().process_frame
	var level := Level.get_active()
	if level != null:
		level.load_depth(depth, from)
	else:
		_pending_depth = depth
		_pending_from = from
		Game.change_scene(LEVEL_SCENE)
		await EventBus.level_loaded
	loading_screen.hide_screen()
	is_transitioning = false


## Für Level._ready(): Ziel eines laufenden Szenenwechsels, sonst fallback.
## Liefert Vector2i(Ziel-Ebene, vorherige Ebene).
func consume_pending(fallback_depth: int) -> Vector2i:
	var result := Vector2i(fallback_depth, current_depth)
	if _pending_depth >= 0:
		result = Vector2i(_pending_depth, _pending_from)
	_pending_depth = -1
	_pending_from = -1
	return result


## Öffnet das Rückkehrportal im Bossraum (ruft AP9 nach dem Sieg über den Boss auf).
func open_portal() -> void:
	var level := Level.get_active()
	if level != null:
		level.set_portal_active(true)
