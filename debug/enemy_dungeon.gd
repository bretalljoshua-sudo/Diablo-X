extends Node3D
## Zweite Testszene von AP3: Gegner in einer echten Dungeon-Ebene aus AP6.
## Start: --scene=enemy_dungeon [--depth=2] [--seed=123] [--bot]
##
## Der EnemyDirector füllt jede geladene Ebene aus data/enemies/spawn_tables/depth_<n>.tres:
## an jedem Spawnpunkt eine Gruppe, manche davon mit Elite-Anführer. Treppen führen wie im
## Spiel zur nächsten Ebene, die Gegner der alten Ebene werden dabei weggeräumt.
## Tasten: F5 neuer Dungeon auf dieser Ebene, B Bot an/aus (läuft zum nächsten Gegner).

@onready var level: Level = $Level
@onready var director: EnemyDirector = $Director
@onready var bot: ArenaBot = $Bot
@onready var status_label: Label = $Hud/Status


func _ready() -> void:
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	level.load_depth(_depth_from_args(args))
	bot.enabled = args.has("--bot")


func _process(_delta: float) -> void:
	if bot.player == null and level.player is Player:
		bot.player = level.player as Player
	var alive := director.get_alive()
	var elites := alive.filter(func(enemy: Enemy) -> bool: return enemy.is_elite).size()
	status_label.text = (
		"%s · %d Gegner (%d Elite) · Physik %.2f ms\nF5: neuer Dungeon · B: Bot %s"
		% [
			World.depth_title(level.depth),
			alive.size(),
			elites,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"an" if bot.enabled else "aus",
		]
	)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F5:
			World.travel_to(maxi(level.depth, 1), true)
		KEY_B:
			bot.enabled = not bot.enabled


static func _depth_from_args(args: PackedStringArray) -> int:
	for arg in args:
		if arg.begins_with("--depth="):
			return clampi(arg.trim_prefix("--depth=").to_int(), 1, 2)
	return 1
