extends SimTest
## Simulationstests für die AP2-Testszene combat_test: Laufen um Hindernisse, WASD,
## Ausweichrolle, Heiltrank, Mausauswahl und Kampf gegen Trainingspuppen.

## Mauer in der Testszene (Mitte und halbe Größe, waagerecht), siehe debug/combat_test.tscn.
const WALL_CENTER := Vector3(0, 0, 0)
const WALL_HALF := Vector3(8, 0, 0.5)

var _scene: Node3D
var _player: Player


func before_each() -> void:
	Combat.hit_stop_enabled = false
	_scene = await load_scene("combat_test")
	_player = _scene.get("player")
	_player.input_enabled = false
	# Navigationsnetz braucht ein paar Physik-Takte, bis es auf der Karte ist.
	await wait_physics_frames(5)


func after_each() -> void:
	Combat.hit_stop_enabled = true
	Engine.time_scale = 1.0
	Input.action_release(&"move_up")


## Wartet, bis condition true liefert oder timeout (Sekunden) abgelaufen ist.
func _wait_until(condition: Callable, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if condition.call():
			return true
		await wait_physics_frames(1)
		waited += 1.0 / Engine.physics_ticks_per_second
	return condition.call()


func test_scene_has_player_dummies_and_navmesh() -> void:
	assert_not_null(_player)
	assert_eq(Game.player, _player, "Spieler meldet sich bei Game an")
	assert_gt(_scene.get_dummies().size(), 3)
	var region: NavigationRegion3D = _scene.get("nav_region")
	assert_gt(region.navigation_mesh.get_polygon_count(), 0, "Navigationsnetz gebacken")


func test_player_walks_around_wall_to_click_target() -> void:
	var start := _player.global_position
	var goal := Vector3(0, 0, -4)
	var crossed_inside_wall := false
	var travelled := 0.0
	var last := start
	_player.move_to(goal)
	var waited := 0.0
	while waited < 8.0 and _player.has_move_target():
		await wait_physics_frames(1)
		waited += 1.0 / Engine.physics_ticks_per_second
		var pos := _player.global_position
		travelled += Vector2(pos.x - last.x, pos.z - last.z).length()
		last = pos
		var local := pos - WALL_CENTER
		if absf(local.x) < WALL_HALF.x and absf(local.z) < WALL_HALF.z:
			crossed_inside_wall = true
	var final := _player.global_position
	assert_lt(
		Vector2(final.x - goal.x, final.z - goal.z).length(), 0.6, "Ziel erreicht: %s" % final
	)
	assert_false(crossed_inside_wall, "nie durch die Mauer")
	assert_gt(travelled, start.distance_to(goal) + 3.0, "Umweg um die Mauer gelaufen")


func test_wasd_moves_relative_to_camera() -> void:
	_player.input_enabled = true
	var start := _player.global_position
	await hold_action(&"move_up", 0.4)
	var moved := _player.global_position - start
	moved.y = 0.0
	var rig := CameraRig.get_active()
	var screen_up := Basis(Vector3.UP, deg_to_rad(rig.yaw_degrees)) * Vector3.FORWARD
	assert_gt(moved.length(), 1.0, "bewegt: %s" % moved)
	assert_gt(moved.normalized().dot(screen_up), 0.95, "W läuft nach Bildschirm-oben")


func test_dodge_moves_fast_is_invulnerable_and_has_cooldown() -> void:
	var start := _player.global_position
	assert_true(_player.dodge(Vector3.RIGHT))
	assert_true(_player.health.is_invulnerable())
	assert_false(_player.dodge(Vector3.RIGHT), "Abklingzeit")
	var result := Combat.apply_damage(HitInfo.create(null, _player, 50.0))
	assert_true(result.evaded, "Treffer während der Rolle geht ins Leere")
	await _wait_until(func() -> bool: return _player.state != Player.State.DODGING, 1.0)
	assert_false(_player.health.is_invulnerable())
	var distance := _player.global_position.x - start.x
	assert_between(distance, 3.5, 5.0, "rund 4,5 m gerollt")
	assert_gt(_player.get_dodge_cooldown_left(), 0.0)


func test_dodge_key_and_potion_key() -> void:
	_player.input_enabled = true
	_player.health.take_damage(100.0)
	var life := _player.health.current
	var charges := _player.potions.charges
	await tap_action(&"potion")
	assert_gt(_player.health.current, life, "Q heilt")
	assert_eq(_player.potions.charges, charges - 1)
	await tap_action(&"dodge")
	assert_true(
		_player.state == Player.State.DODGING or _player.get_dodge_cooldown_left() > 0.0,
		"Leertaste rollt"
	)


func test_mouse_picks_dummy_under_cursor() -> void:
	var dummy: TrainingDummy = _scene.get_passive_dummies()[0]
	await wait_process_frames(10)
	var camera := CameraRig.get_active().camera
	var screen := camera.unproject_position(dummy.global_position + Vector3(0, 1.2, 0))
	assert_eq(_player.pick_target_at_screen(screen), dummy, "Puppe unter der Maus")
	var empty := camera.unproject_position(Vector3(-14, 0, 14))
	assert_null(_player.pick_target_at_screen(empty), "leerer Boden")


func test_player_defeats_all_passive_dummies() -> void:
	var dummies: Array[TrainingDummy] = _scene.get_passive_dummies()
	for dummy in dummies:
		dummy.respawn_time = 0.0
	var hits := [0]
	_player.attack_landed.connect(func(t: Array[Node3D]) -> void: hits[0] += t.size())
	watch_signals(EventBus)
	# Dreifache Geschwindigkeit, damit der Test schnell bleibt (Physik läuft trotzdem in Takten).
	Engine.time_scale = 3.0
	for dummy in dummies:
		_player.attack(dummy, true)
		var dead := await _wait_until(func() -> bool: return dummy.is_dead(), 20.0)
		assert_true(dead, "%s besiegt" % dummy.name)
	assert_gt(hits[0], 0)
	assert_signal_emit_count(EventBus, "entity_died", dummies.size())
	assert_false(_player.is_dead())


func test_attacking_dummy_hits_back_and_slows() -> void:
	var dummy: TrainingDummy = _scene.get_node("Dummies/DummySlow")
	_player.global_position = dummy.global_position + Vector3(-1.5, 0, 0)
	var life := _player.health.current
	var slowed := await _wait_until(
		func() -> bool: return _player.status_effects.has_effect(&"slow"), 4.0
	)
	assert_true(slowed, "Gegenangriff verlangsamt")
	assert_lt(_player.health.current, life)
	assert_lt(
		Stats.get_stat(_player, Enums.Stat.MOVE_SPEED),
		_player.stats.base_stats.get_value(Enums.Stat.MOVE_SPEED)
	)


func test_stun_blocks_actions_and_player_death() -> void:
	var stun := load("res://data/status_effects/stun.tres") as StatusEffectDef
	_player.status_effects.apply(stun)
	await wait_physics_frames(2)
	assert_eq(_player.state, Player.State.STUNNED)
	assert_false(_player.dodge(Vector3.LEFT), "betäubt: keine Rolle")
	var free := await _wait_until(func() -> bool: return _player.state != Player.State.STUNNED, 2.0)
	assert_true(free, "Betäubung endet")
	watch_signals(EventBus)
	Combat.apply_damage(HitInfo.create(null, _player, 10000.0))
	await wait_physics_frames(2)
	assert_eq(_player.state, Player.State.DEAD)
	assert_signal_emitted(EventBus, "entity_died")
	_player.revive()
	assert_eq(_player.state, Player.State.IDLE)
	assert_eq(_player.health.current, _player.health.maximum)
