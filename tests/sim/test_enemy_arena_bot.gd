extends SimTest
## „Fertig, wenn“ von AP3, Teil 1: Ein Bot-Spieler besteht die Arena (alle Wellen, inklusive
## Elite-Gegner) nur mit Standardangriff, Ausweichrolle und Heiltränken.

## Die Simulation läuft beschleunigt, damit der Test nicht minutenlang dauert.
const TIME_SCALE := 3.0
const TIMEOUT_GAME_SECONDS := 240.0


func before_each() -> void:
	Combat.hit_stop_enabled = false
	Rng.set_master_seed(20260922)


func after_each() -> void:
	Combat.hit_stop_enabled = true
	Engine.time_scale = 1.0


func test_bot_clears_the_arena() -> void:
	var arena: Node3D = await load_scene("enemy_arena")
	var player: Player = arena.get("player")
	player.input_enabled = false
	var bot: ArenaBot = arena.get("bot")
	bot.enabled = true
	Engine.time_scale = TIME_SCALE
	var waves_seen: Array[int] = []
	arena.wave_started.connect(func(index: int) -> void: waves_seen.append(index))
	var game_time := 0.0
	var phase: int = arena.get("phase")
	while game_time < TIMEOUT_GAME_SECONDS:
		await wait_physics_frames(30)
		game_time += 30.0 * TIME_SCALE / Engine.physics_ticks_per_second
		phase = arena.get("phase")
		if phase == arena.Phase.COMPLETED or phase == arena.Phase.FAILED:
			break
	Engine.time_scale = 1.0
	(
		gut
		. p(
			(
				"Arena: Phase %d nach %.0f s Spielzeit, Wellen %s, besiegt %d, Rollen %d, Tränke %d, Leben %d"
				% [
					phase,
					game_time,
					waves_seen,
					arena.get("kills"),
					bot.dodges,
					bot.potions_used,
					ceili(player.health.current)
				]
			)
		)
	)
	assert_eq(phase, arena.Phase.COMPLETED, "Bot besteht die Arena")
	assert_eq(waves_seen.size(), (arena.get("waves") as Array).size(), "alle Wellen gespielt")
	assert_false(player.is_dead(), "Spieler lebt")
	assert_gt(bot.dodges, 0, "Bot ist Vorwarnungen ausgewichen")
	assert_gt(arena.get("experience_gained"), 0, "Erfahrung vergeben")
