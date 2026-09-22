extends SimTest
## „Fertig, wenn“ von AP3, Teil 2: 60 aktive Gegner kosten unter 3 ms pro Physik-Takt
## (headless gemessen, siehe PhysicsTickProbe). Die Gegner verfolgen und greifen einen
## unverwundbaren Spieler an, damit alle 60 die ganze Zeit aktiv sind.

const BUDGET_MS := 3.0
const SAMPLE_TICKS := 300


func before_each() -> void:
	Combat.hit_stop_enabled = false
	Rng.set_master_seed(4242)


func after_each() -> void:
	Combat.hit_stop_enabled = true


func test_sixty_active_enemies_stay_within_budget() -> void:
	var arena: Node3D = await load_scene("enemy_arena")
	arena.set_free_play()
	var player: Player = arena.get("player")
	player.input_enabled = false
	player.health.set_invulnerable(&"test", true)
	player.global_position = Vector3(0, 0, 4)
	var probe := PhysicsTickProbe.new()
	add_child_autofree(probe)
	await wait_physics_frames(5)
	var enemies: Array[Enemy] = arena.spawn_stress()
	assert_eq(enemies.size(), 60)
	for enemy in enemies:
		enemy.brain.notice(player, 0.0)
	# Einschwingen: alle laufen los, Wege sind berechnet.
	await wait_physics_frames(90)
	var fighting: Array[int] = []
	probe.recording = true
	var start_frame := Engine.get_physics_frames()
	while Engine.get_physics_frames() - start_frame < SAMPLE_TICKS:
		await wait_physics_frames(30)
		fighting.append(_count_fighting(enemies))
	probe.recording = false
	var engine_max := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	gut.p(
		(
			(
				"60 Gegner über %d Takte: Mittel %.3f ms, Median %.3f ms, 95 %% %.3f ms,"
				+ " Godot-Monitor (größter Takt der letzten Sekunde) %.3f ms, aktiv %s"
			)
			% [
				probe.samples_ms.size(),
				probe.mean(),
				probe.percentile(0.5),
				probe.percentile(0.95),
				engine_max,
				fighting
			]
		)
	)
	for count in fighting:
		assert_eq(count, 60, "alle 60 Gegner sind aktiv (verfolgen oder greifen an)")
	assert_gt(probe.samples_ms.size(), SAMPLE_TICKS / 2)
	assert_lt(probe.mean(), BUDGET_MS, "Mittel unter %.1f ms pro Physik-Takt" % BUDGET_MS)
	assert_lt(probe.percentile(0.5), BUDGET_MS, "Median unter %.1f ms" % BUDGET_MS)


func _count_fighting(enemies: Array[Enemy]) -> int:
	var count := 0
	for enemy in enemies:
		var state := enemy.get_state()
		if (
			state == AIBrain.State.CHASE
			or state == AIBrain.State.ATTACK
			or state == AIBrain.State.RECOVER
			or state == AIBrain.State.NOTICE
		):
			count += 1
	return count
