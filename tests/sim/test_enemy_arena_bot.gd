extends SimTest
## „Fertig, wenn“ von AP3, Teil 1: Ein Bot-Spieler besteht die Arena (alle Wellen, inklusive
## Elite-Gegner) nur mit Standardangriff, Ausweichrolle und Heiltränken.

## Die Simulation läuft beschleunigt, damit der Test nicht minutenlang dauert.
const TIME_SCALE := 3.0
const TIMEOUT_GAME_SECONDS := 240.0

## Fester Seed. Mit der Umgebungsvariable ARENA_BOT_SEED lassen sich andere Seeds prüfen.
const SEED := 20260922


func before_each() -> void:
	Combat.hit_stop_enabled = false
	var custom := OS.get_environment("ARENA_BOT_SEED")
	Rng.set_master_seed(custom.to_int() if custom.is_valid_int() else SEED)
	# Kritische Treffer würfelt Combat aus einem eigenen Strom, der beim Start des Spiels
	# entsteht. Neu aus dem festen Seed abgeleitet, ist auch dieser Zufall jedes Mal gleich.
	Combat.set_rng(Rng.stream(&"combat"))


func after_each() -> void:
	Combat.hit_stop_enabled = true
	Engine.time_scale = 1.0


func test_bot_clears_the_arena() -> void:
	var arena: Node3D = await load_scene("enemy_arena")
	var player: Player = arena.get("player")
	player.input_enabled = false
	# Der Treffer des Spielers kommt aus der Animation. Läuft sie im Physik-Takt statt im
	# Bild-Takt, hängt der Lauf nicht mehr von der Bildrate der Maschine ab und ist mit
	# demselben Seed jedes Mal gleich.
	var anim_tree := player.model.get(&"anim_tree") as AnimationTree
	if anim_tree != null:
		anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	var bot: ArenaBot = arena.get("bot")
	# Wie viele Physik-Takte beim Laden vergehen, hängt von der Maschine ab. Deshalb startet die
	# Arena erst hier, genau zu Beginn eines Takts, neu; ab dann ist jeder Lauf gleich.
	await wait_physics_frames(1)
	arena.restart()
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
	gut.p(
		(
			(
				"Arena (Seed %d): Phase %d nach %.0f s Spielzeit, Wellen %s, besiegt %d, "
				+ "Rollen %d, Tränke %d, Leben %d"
			)
			% [
				Rng.master_seed,
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
	if phase != arena.Phase.COMPLETED:
		gut.p(_describe(arena, player))
	assert_eq(phase, arena.Phase.COMPLETED, "Bot besteht die Arena")
	assert_eq(waves_seen.size(), (arena.get("waves") as Array).size(), "alle Wellen gespielt")
	assert_false(player.is_dead(), "Spieler lebt")
	assert_gt(bot.dodges, 0, "Bot ist Vorwarnungen ausgewichen")
	assert_gt(arena.get("experience_gained"), 0, "Erfahrung vergeben")


## Lage beim Abbruch, damit ein roter Lauf sich erklären lässt.
func _describe(arena: Node3D, player: Player) -> String:
	var lines: PackedStringArray = []
	lines.append(
		(
			"Spieler bei %s, Zustand %d, Ziel %s"
			% [
				player.global_position.snapped(Vector3.ONE * 0.1),
				player.state,
				player.attack_target
			]
		)
	)
	var director: EnemyDirector = arena.get("director")
	for enemy in director.get_alive():
		lines.append(
			(
				"  %s bei %s, KI %d, Leben %d, Schild %s"
				% [
					enemy.type.id,
					enemy.global_position.snapped(Vector3.ONE * 0.1),
					enemy.get_state(),
					ceili(enemy.health.current),
					enemy.has_shield()
				]
			)
		)
	return "\n".join(lines)
