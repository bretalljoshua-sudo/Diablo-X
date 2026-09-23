class_name GameSession
extends Node3D
## Die Spielszene von Version 0.1 (encounters/game.tscn): verbindet alle Pakete zu einer Runde.
##
##   Dorf (Händlerin) → Katakomben Ebene 1 → Ebene 2 → Gruft des Wächters (Boss) → Portal → Dorf
##
## Aufbau: Level (AP6) mit Spielerfigur (AP2, Skills AP5, Beute AP4), EnemyDirector (AP3) füllt die
## Ebenen nach der Schwierigkeitskurve, BossArena und BossController (AP9) für den Boss,
## GameUI (AP7), Effekte, Kamera (AP1), Musik. Tod: DeathScreen, Erwachen am Eingang oder im Dorf.
## Speichern: bei jedem Ebenenwechsel, Stufenaufstieg, Sieg, alle AUTOSAVE_INTERVAL s und beim
## Beenden. „Weiter“ auf dem Titelbildschirm lädt den Stand und beginnt im Dorf.
##
## Startart über GameSession.launch_mode (Titelbildschirm) oder Kommandozeile (für Tests):
##   --new-game / --continue      neues Spiel oder Spielstand laden
##   --start-depth=<0..3>         auf einer anderen Ebene beginnen (Standard 0, das Dorf)
##   --level=<1..10>              Startstufe für ein neues Spiel
##   --bot                        der RunBot spielt (Simulation, Zuschauen)
##   --no-save                    nichts speichern
##   --save-path=<pfad>           anderer Spielstand (Tests), sonst user://savegame.json
##   --quit-after-run             nach geschafftem Durchlauf zurück im Dorf speichern, Ergebnis
##                                ausgeben (Zeile „GameSession: Ergebnis {…}“) und beenden

signal run_started
signal run_finished(duration_sec: float)
signal saved

enum LaunchMode { NEW_GAME, CONTINUE }

const TITLE_SCENE := "res://encounters/title_screen.tscn"
const PLAYER_SCENE := "res://player/player.tscn"
const AUTOSAVE_INTERVAL := 60.0
const DEATH_SCREEN_DELAY := 1.4
const RESULT_PREFIX := "GameSession: Ergebnis "

## Vom Titelbildschirm gesetzt, gilt für den nächsten Start der Szene.
static var launch_mode: LaunchMode = LaunchMode.NEW_GAME

@export var start_depth: int = 0
@export var start_level: int = 1
@export var save_enabled: bool = true
@export var bot_enabled: bool = false
## Liest die Kommandozeile (--bot, --level, …). Tests schalten das ab.
@export var read_command_line: bool = true
## Nach dem ersten geschafften Durchlauf im Dorf beenden (Simulationstest).
@export var quit_after_run: bool = false

var player: Player
var skills: SkillUser
var progress: Dictionary = SaveGame.new_progress()
var curve: DifficultyCurve
var merchant: VillageMerchant
var death_screen: DeathScreen
var bot: Node
var run_active: bool = false
var run_time: float = 0.0
## Zuletzt abgeschlossener Durchlauf in Sekunden (0 = noch keiner).
var last_run_sec: float = 0.0
var mode: LaunchMode = LaunchMode.NEW_GAME
## Höchste Bossphase im laufenden Durchlauf (für Auswertung und Tests).
var boss_phase_reached: int = 0

var _autosave_left: float = AUTOSAVE_INTERVAL
var _loaded_data: Dictionary = {}

@onready var level: Level = $Level
@onready var director: EnemyDirector = $Director
@onready var arena: BossArena = $BossArena
@onready var game_ui: GameUI = $GameUI
@onready var music: MusicDirector = $Music


func _ready() -> void:
	curve = DifficultyCurve.get_default()
	mode = launch_mode
	if read_command_line:
		_read_args(OS.get_cmdline_user_args() + OS.get_cmdline_args())
	get_tree().auto_accept_quit = false
	director.auto_populate = false
	arena.level_provider = func() -> int: return curve.enemy_level(World.BOSS_DEPTH, player_level())
	arena.boss_defeated.connect(_on_boss_defeated)
	EventBus.level_loaded.connect(_on_level_loaded)
	EventBus.level_transition_started.connect(_on_transition_started)
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.player_level_up.connect(_on_player_level_up)
	EventBus.boss_phase_changed.connect(
		func(_boss: Node3D, phase: int) -> void:
			boss_phase_reached = maxi(boss_phase_reached, phase)
	)
	death_screen = DeathScreen.new()
	death_screen.revive_requested.connect(revive)
	add_child(death_screen)
	_extend_pause_menu()
	_spawn_player()
	if mode == LaunchMode.CONTINUE:
		_loaded_data = SaveGame.read()
		if _loaded_data.is_empty():
			push_warning("GameSession: kein Spielstand gefunden, starte ein neues Spiel.")
			mode = LaunchMode.NEW_GAME
	if mode == LaunchMode.CONTINUE:
		SaveGame.apply(player, _loaded_data)
		progress = SaveGame.progress_of(_loaded_data)
		print("GameSession: Spielstand geladen (%s)" % SaveGame.summary(_loaded_data))
	elif start_level > 1 and skills != null:
		skills.set_level(start_level)
		player.health.reset_to_full()
	if start_depth > World.VILLAGE_DEPTH:
		World.start_new_run()
	level.load_depth(start_depth)
	if start_depth > World.VILLAGE_DEPTH:
		_begin_run()
	if bot_enabled:
		_start_bot()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	progress["play_time_sec"] = float(progress.get("play_time_sec", 0.0)) + delta
	if run_active:
		run_time += delta
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = AUTOSAVE_INTERVAL
		save_now()


func _exit_tree() -> void:
	get_tree().auto_accept_quit = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()
		get_tree().quit()


func player_level() -> int:
	return skills.progression.level if skills != null else 1


## Speichert sofort (wenn erlaubt). Tote Figuren werden nicht gespeichert, erst nach dem Erwachen.
func save_now() -> Error:
	if not save_enabled or player == null or not is_instance_valid(player):
		return ERR_UNAVAILABLE
	var err := SaveGame.write(player, progress)
	if err == OK:
		saved.emit()
	return err


## Speichert und kehrt zum Titelbildschirm zurück.
func return_to_title() -> void:
	save_now()
	get_tree().paused = false
	get_tree().auto_accept_quit = true
	Game.change_scene(TITLE_SCENE)


## Wiederbeleben nach dem Tod. where: &"level" = am Eingang der Ebene, &"village" = im Dorf.
func revive(where: StringName = &"level") -> void:
	if player == null or not player.is_dead():
		return
	death_screen.hide_screen()
	arena.reset_encounter()
	player.revive()
	if where == &"village" or level.depth <= World.VILLAGE_DEPTH:
		_abort_run()
		World.travel_to(World.VILLAGE_DEPTH)
	else:
		player.global_position = level.layout.player_start
		player.velocity = Vector3.ZERO
		player.stop()
		var rig := CameraRig.get_active()
		if rig != null:
			rig.snap_to_target()
	save_now()


# --- Aufbau ------------------------------------------------------------------------------------


func _spawn_player() -> void:
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.name = "Player"
	level.actors.add_child(player)
	Game.player = player
	level.player = player
	skills = SkillUser.find_on(player)
	game_ui.bind_player(player)


func _start_bot() -> void:
	var script := load("res://debug/run_bot.gd") as GDScript
	if script == null:
		return
	bot = script.new() as Node
	bot.name = "RunBot"
	bot.set(&"session", self)
	bot.set(&"player", player)
	bot.set(&"enabled", true)
	bot.set(&"log_interval", 10.0)
	add_child(bot)


## Knopf „Speichern und zum Titel“ im Pausenmenü (AP7), Speichern beim Beenden.
func _extend_pause_menu() -> void:
	var menu := game_ui.pause_menu
	var button := Button.new()
	button.name = "TitleButton"
	button.text = "Speichern und zum Titel"
	button.pressed.connect(return_to_title)
	menu.main_page.add_child(button)
	var quit_button := menu.main_page.get_node_or_null(^"SpielbeendenButton")
	if quit_button != null:
		menu.main_page.move_child(button, quit_button.get_index())
	menu.quit_requested.connect(func() -> void: save_now())


func _read_args(args: PackedStringArray) -> void:
	for arg in args:
		if arg == "--new-game":
			mode = LaunchMode.NEW_GAME
		elif arg == "--continue":
			mode = LaunchMode.CONTINUE
		elif arg == "--bot":
			bot_enabled = true
		elif arg == "--no-save":
			save_enabled = false
		elif arg == "--quit-after-run":
			quit_after_run = true
		elif arg.begins_with("--save-path="):
			SaveService.save_path = arg.trim_prefix("--save-path=")
		elif arg.begins_with("--start-depth="):
			start_depth = clampi(arg.trim_prefix("--start-depth=").to_int(), 0, World.BOSS_DEPTH)
		elif arg.begins_with("--level="):
			start_level = clampi(arg.trim_prefix("--level=").to_int(), 1, 10)


# --- Ebenen ------------------------------------------------------------------------------------


func _on_level_loaded(layout: LevelLayout) -> void:
	if layout.depth == World.VILLAGE_DEPTH:
		_setup_village(layout)
		if quit_after_run and last_run_sec > 0.0:
			_finish_and_quit.call_deferred()
	elif layout.depth < World.BOSS_DEPTH:
		_populate(layout)
	save_now.call_deferred()


func _setup_village(layout: LevelLayout) -> void:
	if not layout.markers.has(&"merchant"):
		return
	merchant = VillageMerchant.new()
	merchant.name = "Merchant"
	merchant.ui = game_ui
	level.actors.add_child(merchant)
	merchant.global_position = layout.markers[&"merchant"]
	var towards: Vector3 = layout.player_start - merchant.global_position
	towards.y = 0.0
	if towards.length_squared() > 0.01:
		merchant.rotation.y = atan2(towards.x, towards.z)
	merchant.restock(player_level())


## Füllt eine Dungeon-Ebene, sobald ihr Navigationsnetz steht (wie EnemyDirector.auto_populate,
## aber mit Stufe und Dichte aus der Schwierigkeitskurve).
func _populate(layout: LevelLayout) -> void:
	var table := curve.spawn_table_for(layout.depth, player_level())
	if table == null:
		return
	if not layout.spawn_points.is_empty():
		for i in 30:
			if _on_navigation(layout.spawn_points[0]):
				break
			await get_tree().physics_frame
	if level.layout != layout:
		return
	var enemies := director.populate(layout, table)
	print(
		(
			"GameSession: Ebene %d mit %d Gegnern der Stufe %d (Spieler Stufe %d)"
			% [layout.depth, enemies.size(), table.level, player_level()]
		)
	)


func _on_navigation(point: Vector3) -> bool:
	var map := get_world_3d().navigation_map
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var closest := NavigationServer3D.map_get_closest_point(map, point)
	return Vector2(closest.x - point.x, closest.z - point.z).length() < 1.0


func _on_transition_started(target_depth: int) -> void:
	if merchant != null and is_instance_valid(merchant):
		merchant.close_shop()
	if World.current_depth <= World.VILLAGE_DEPTH and target_depth > World.VILLAGE_DEPTH:
		_begin_run()
	elif target_depth <= World.VILLAGE_DEPTH and run_active:
		_abort_run()


# --- Durchlauf, Tod, Sieg ----------------------------------------------------------------------


func _begin_run() -> void:
	run_active = true
	run_time = 0.0
	boss_phase_reached = 0
	run_started.emit()


func _abort_run() -> void:
	run_active = false


func _on_boss_defeated(_boss: Enemy) -> void:
	progress["boss_kills"] = int(progress.get("boss_kills", 0)) + 1
	if run_active:
		run_active = false
		last_run_sec = run_time
		progress["runs_completed"] = int(progress.get("runs_completed", 0)) + 1
		var best := float(progress.get("best_run_sec", 0.0))
		if best <= 0.0 or run_time < best:
			progress["best_run_sec"] = run_time
		print("GameSession: Durchlauf geschafft in %.0f s" % run_time)
		EventBus.run_completed.emit(run_time)
		run_finished.emit(run_time)
	save_now()


func _on_entity_died(entity: Node3D, _killer: Node3D) -> void:
	if entity == null or entity != player:
		return
	progress["deaths"] = int(progress.get("deaths", 0)) + 1
	var lost := 0
	var inventory := player.inventory
	if inventory != null and inventory.gold > 0:
		lost = int(floorf(inventory.gold * curve.death_gold_loss))
		if lost > 0:
			inventory.spend_gold(lost)
	await get_tree().create_timer(DEATH_SCREEN_DELAY).timeout
	if is_instance_valid(player) and player.is_dead():
		death_screen.show_screen(lost, level.depth > World.VILLAGE_DEPTH)


func _on_player_level_up(_level: int) -> void:
	save_now.call_deferred()


## Kennzahlen des letzten Durchlaufs (Simulationstest, Balancing).
func result() -> Dictionary:
	var data := {
		"run_sec": snappedf(last_run_sec, 0.1),
		"level": player_level(),
		"boss_phase": boss_phase_reached,
		"boss_attempts": arena.attempts,
		"boss_fight_sec": snappedf(arena.fight_time, 0.1),
		"gold": player.inventory.gold if player != null and player.inventory != null else 0,
		"progress": progress,
		"depth": level.depth,
	}
	if bot != null and bot.has_method(&"stats"):
		data["bot"] = bot.call(&"stats")
	return data


func _finish_and_quit() -> void:
	save_now()
	print(RESULT_PREFIX + JSON.stringify(result()))
	get_tree().quit()
