extends SimTest
## Bosskampf (AP9) in der Testszene boss_test: Bossraum schließt sich, zweite Phase unter 50 %
## mit Beschwörungen und Feuerflächen, Sieg öffnet Tor, Truhe und Portal. Tod und Wiederbeleben
## setzen den Kampf zurück.

const TIME_SCALE := 2.0

var _phases: Array[int] = []
var _runs: Array[float] = []


func before_each() -> void:
	Combat.hit_stop_enabled = false
	Rng.set_master_seed(20260923)
	_phases.clear()
	_runs.clear()
	EventBus.boss_phase_changed.connect(_on_phase)
	EventBus.run_completed.connect(_on_run)


func after_each() -> void:
	Engine.time_scale = 1.0
	Combat.hit_stop_enabled = true
	EventBus.boss_phase_changed.disconnect(_on_phase)
	EventBus.run_completed.disconnect(_on_run)


func _on_phase(_boss: Node3D, phase: int) -> void:
	_phases.append(phase)


func _on_run(duration: float) -> void:
	_runs.append(duration)


## Wartet, bis condition wahr ist (höchstens timeout Sekunden Spielzeit).
func _wait_for(condition: Callable, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if condition.call():
			return true
		await wait_physics_frames(6)
		waited += 6.0 * Engine.time_scale / Engine.physics_ticks_per_second
	return condition.call()


func _load_boss_room() -> GameSession:
	var game: GameSession = await load_scene("boss_test")
	game.player.input_enabled = false
	var ready := await _wait_for(
		func() -> bool: return game.arena.state == BossArena.State.WAITING, 10.0
	)
	assert_true(ready, "Boss wartet im Bossraum")
	return game


func _enter_boss_room(game: GameSession) -> void:
	game.player.global_position = game.arena.layout.markers[&"boss_room_center"]
	var started := await _wait_for(
		func() -> bool: return game.arena.state == BossArena.State.FIGHTING, 5.0
	)
	assert_true(started, "Kampf beginnt beim Betreten")


## Tödlicher Treffer über Combat (wie im Spiel, mit entity_died).
func _kill(target: Node3D, source: Node3D) -> void:
	var health := Components.health(target)
	health.set_invulnerable(&"test", false)
	var hit := HitInfo.create(source, target, health.current * 50.0 + 10000.0)
	hit.can_crit = false
	Combat.apply_damage(hit)


func _portal_active() -> bool:
	for node in Level.get_active().find_children("*", "ExitTrigger", true, false):
		var trigger := node as ExitTrigger
		if trigger.target_depth == World.VILLAGE_DEPTH and trigger.active:
			return true
	return false


func test_boss_room_locks_phases_and_rewards() -> void:
	var game := await _load_boss_room()
	var arena := game.arena
	assert_eq(arena.boss.type.display_name, "Der Gruftwächter")
	assert_false(arena.gate.is_closed, "Tor offen, bevor der Kampf beginnt")
	assert_false(_portal_active(), "Portal zu, solange der Boss lebt")
	Engine.time_scale = TIME_SCALE
	await _enter_boss_room(game)
	assert_true(arena.gate.is_closed, "Tor schließt den Spieler ein")
	game.player.health.set_invulnerable(&"test", true)

	var boss := arena.boss
	boss.health.take_damage(boss.health.maximum * 0.55, game.player)
	var phase_two := await _wait_for(func() -> bool: return arena.controller.phase == 2, 3.0)
	assert_true(phase_two, "zweite Phase unter 50 % Leben")
	assert_has(_phases, 2, "boss_phase_changed mit Phase 2")
	var fire := await _wait_for(func() -> bool: return arena.controller.fire_waves > 0, 10.0)
	assert_true(fire, "Feuerflächen in Phase 2")
	assert_gt(get_tree().get_nodes_in_group(FirePatch.GROUP).size(), 0)
	var summoned := await _wait_for(
		func() -> bool:
			for node in get_tree().get_nodes_in_group(Enemy.GROUP):
				var enemy := node as Enemy
				if enemy.summoner == boss and enemy.is_active():
					return true
			return false,
		20.0
	)
	assert_true(summoned, "Boss beschwört Skelette")

	await _wait_for(func() -> bool: return not arena.controller.is_roaring(), 3.0)
	_kill(boss, game.player)
	var won := await _wait_for(func() -> bool: return arena.state == BossArena.State.DEFEATED, 3.0)
	assert_true(won, "Boss besiegt")
	assert_false(arena.gate.is_closed, "Tor geht nach dem Sieg auf")
	assert_true(_portal_active(), "Portal ins Dorf offen")
	assert_eq(_runs.size(), 1, "run_completed gesendet")
	assert_not_null(arena.chest, "Belohnungstruhe erscheint")
	game.player.global_position = arena.chest.global_position + Vector3(1.2, 0, 0)
	var opened := await _wait_for(func() -> bool: return arena.chest.is_open, 3.0)
	assert_true(opened, "Truhe öffnet sich")
	assert_gte(arena.chest.dropped.size(), 1, "Truhe enthält Gegenstände")
	# Den Truhenklang ausklingen lassen, sonst hängt er beim Beenden noch im AudioServer.
	Engine.time_scale = 1.0
	await wait_seconds(3.0)


func test_death_resets_the_fight_and_revives_at_entrance() -> void:
	var game := await _load_boss_room()
	var arena := game.arena
	Engine.time_scale = TIME_SCALE
	game.player.inventory.add_gold(500)
	await _enter_boss_room(game)
	var boss := arena.boss
	boss.health.take_damage(boss.health.maximum * 0.6, game.player)
	await _wait_for(func() -> bool: return arena.controller.phase == 2, 3.0)

	_kill(game.player, boss)
	var shown := await _wait_for(func() -> bool: return game.death_screen.is_showing(), 4.0)
	assert_true(shown, "Todesbildschirm erscheint")
	assert_eq(game.player.inventory.gold, 450, "Tod kostet 10 % Gold")
	assert_true(game.death_screen.level_button.visible, "Erwachen am Eingang möglich")
	game.death_screen.level_button.pressed.emit()
	await wait_physics_frames(4)

	assert_false(game.player.is_dead(), "Spieler lebt wieder")
	assert_false(game.death_screen.is_showing())
	var start := game.level.layout.player_start
	assert_lt(
		(
			Vector2(
				game.player.global_position.x - start.x, game.player.global_position.z - start.z
			)
			. length()
		),
		1.5,
		"am Eingang der Ebene"
	)
	assert_eq(arena.state, BossArena.State.WAITING, "Kampf zurückgesetzt")
	assert_eq(arena.controller.phase, 1, "Boss wieder in Phase 1")
	assert_eq(boss.health.current, boss.health.maximum, "Boss wieder voll")
	assert_false(arena.gate.is_closed, "Tor wieder offen")
	assert_eq(int(game.progress["deaths"]), 1)
