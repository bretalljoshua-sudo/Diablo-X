extends SimTest
## Simulationstests für Gegner und KI (AP3) in der Arena ohne Wellen: Zustandsautomat,
## Vorwarnung und faires Ausweichen, Gruppen, Fernkampf, Beschwören, Tod mit Beute und
## Erfahrung, Objekt-Pool und Elite-Eigenschaften.

const SKELETON := preload("res://data/enemies/skeleton.tres")
const GHOUL := preload("res://data/enemies/ghoul.tres")
const ARCHER := preload("res://data/enemies/skeleton_archer.tres")
const CULTIST := preload("res://data/enemies/cultist.tres")

var _arena: Node3D
var _player: Player
var _director: EnemyDirector


func before_each() -> void:
	Combat.hit_stop_enabled = false
	Rng.set_master_seed(777)
	_arena = await load_scene("enemy_arena")
	_arena.set_free_play()
	_player = _arena.get("player")
	_player.input_enabled = false
	_player.global_position = Vector3(0, 0, 12)
	_director = _arena.get("director")
	await wait_physics_frames(5)


func after_each() -> void:
	Combat.hit_stop_enabled = true
	Engine.time_scale = 1.0


func _wait_until(condition: Callable, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if condition.call():
			return true
		await wait_physics_frames(1)
		waited += 1.0 / Engine.physics_ticks_per_second
	return condition.call()


func _affix(id: String) -> Array[EliteAffix]:
	var list: Array[EliteAffix] = [load("res://data/enemies/elite/%s.tres" % id) as EliteAffix]
	return list


func _kill(enemy: Enemy) -> void:
	enemy.end_shield()
	var hit := HitInfo.create(_player, enemy, 1.0e6)
	hit.can_crit = false
	Combat.apply_damage(hit)


func test_state_machine_idle_notice_chase_attack_recover() -> void:
	var enemy := _director.spawn(SKELETON, Vector3(0, 0, 2))
	var seen: Array[AIBrain.State] = [enemy.get_state()]
	enemy.state_changed.connect(
		func(state: AIBrain.State) -> void:
			if seen[-1] != state:
				seen.append(state)
	)
	assert_eq(enemy.get_state(), AIBrain.State.IDLE, "ruht am Anfang")
	var recovered := await _wait_until(func() -> bool: return seen.has(AIBrain.State.RECOVER), 6.0)
	assert_true(recovered, "Ablauf erreicht Erholen: %s" % [seen])
	assert_eq(
		seen.slice(0, 5),
		[
			AIBrain.State.IDLE,
			AIBrain.State.NOTICE,
			AIBrain.State.CHASE,
			AIBrain.State.ATTACK,
			AIBrain.State.RECOVER
		]
	)
	assert_lt(_player.health.current, _player.health.maximum, "Treffer gelandet")


func test_far_enemy_keeps_resting() -> void:
	_player.global_position = Vector3(18, 0, 18)
	var enemy := _director.spawn(SKELETON, Vector3(-18, 0, -18))
	await wait_seconds(1.0)
	assert_eq(enemy.get_state(), AIBrain.State.IDLE)


func test_enemy_behind_wall_does_not_notice() -> void:
	# Mauer in der Arena: Mitte (0, 0, -8), 6 m breit, 1 m hoch. Spieler dahinter, Gegner davor.
	_player.global_position = Vector3(0, 0, -6.5)
	var enemy := _director.spawn(SKELETON, Vector3(0, 0, -9.3))
	# Die Sichtlinie in Augenhöhe geht über die niedrige Mauer: Gegner sieht den Spieler.
	assert_true(
		await _wait_until(func() -> bool: return enemy.get_state() != AIBrain.State.IDLE, 1.0),
		"niedrige Mauer verdeckt nicht"
	)
	_player.global_position = Vector3(-7, 0, -2.5)
	var hidden := _director.spawn(SKELETON, Vector3(-7, 0, -5.8))
	await wait_seconds(0.6)
	assert_eq(hidden.get_state(), AIBrain.State.IDLE, "Säule verdeckt die Sicht")


func test_telegraph_is_visible_before_the_hit() -> void:
	var enemy := _director.spawn(SKELETON, Vector3(0, 0, 10.5))
	enemy.brain.notice(_player, 0.0)
	assert_true(
		await _wait_until(func() -> bool: return enemy.get_state() == AIBrain.State.ATTACK, 3.0)
	)
	var life := _player.health.current
	assert_true(enemy.telegraph.is_active(), "Vorwarnung sichtbar")
	assert_true(enemy.telegraph.contains_point(_player.global_position, _player.hurtbox.radius))
	assert_eq(_player.health.current, life, "während der Vorwarnung noch kein Schaden")
	var windup := SKELETON.attacks[0].windup
	assert_almost_eq(enemy.telegraph.duration, windup, 0.02)
	await _wait_until(func() -> bool: return enemy.get_state() == AIBrain.State.RECOVER, 2.0)
	assert_false(enemy.telegraph.is_active())
	assert_lt(_player.health.current, life, "Treffer am Ende der Vorwarnung")


func test_leaving_the_telegraph_avoids_the_hit() -> void:
	var enemy := _director.spawn(SKELETON, Vector3(0, 0, 10.5))
	enemy.brain.notice(_player, 0.0)
	await _wait_until(func() -> bool: return enemy.get_state() == AIBrain.State.ATTACK, 3.0)
	var life := _player.health.current
	_player.global_position += Vector3(0, 0, 3.0)
	await _wait_until(func() -> bool: return enemy.get_state() == AIBrain.State.RECOVER, 2.0)
	assert_eq(_player.health.current, life, "wer die Fläche verlässt, wird nicht getroffen")


func test_dodging_through_the_telegraph_avoids_the_hit() -> void:
	var enemy := _director.spawn(GHOUL, Vector3(0, 0, 9.8))
	enemy.brain.notice(_player, 0.0)
	await _wait_until(func() -> bool: return enemy.get_state() == AIBrain.State.ATTACK, 4.0)
	var life := _player.health.current
	await _wait_until(func() -> bool: return enemy.telegraph.get_time_left() < 0.15, 2.0)
	assert_true(_player.dodge(Vector3.LEFT))
	await _wait_until(func() -> bool: return enemy.get_state() == AIBrain.State.RECOVER, 1.0)
	assert_eq(_player.health.current, life, "Rolle macht unverwundbar")


func test_stun_cancels_the_windup() -> void:
	var enemy := _director.spawn(GHOUL, Vector3(0, 0, 9.8))
	enemy.brain.notice(_player, 0.0)
	await _wait_until(func() -> bool: return enemy.get_state() == AIBrain.State.ATTACK, 4.0)
	var life := _player.health.current
	enemy.status_effects.apply(load("res://data/status_effects/stun.tres") as StatusEffectDef)
	await wait_physics_frames(2)
	assert_false(enemy.telegraph.is_active(), "Vorwarnung abgebrochen")
	await wait_seconds(1.2)
	assert_eq(_player.health.current, life, "kein Treffer während der Betäubung")


func test_group_notices_together() -> void:
	var types: Array[EnemyType] = [SKELETON, SKELETON, SKELETON, SKELETON]
	var group := _director.spawn_types(types, Vector3(12, 0, -12))
	_player.global_position = Vector3(12, 0, -3)
	await wait_physics_frames(1)
	group[0].brain.notice(_player)
	await wait_physics_frames(2)
	for enemy in group:
		assert_ne(enemy.get_state(), AIBrain.State.IDLE, "ganze Gruppe bemerkt das Ziel")
		assert_eq(enemy.group_id, group[0].group_id)


func test_damage_wakes_a_resting_enemy() -> void:
	_player.global_position = Vector3(18, 0, 18)
	var enemy := _director.spawn(GHOUL, Vector3(-15, 0, -15))
	Combat.apply_damage(HitInfo.create(_player, enemy, 5.0))
	await wait_physics_frames(2)
	assert_ne(enemy.get_state(), AIBrain.State.IDLE)
	assert_eq(enemy.get_target(), _player)


func test_archer_keeps_distance_and_shoots() -> void:
	_player.health.set_invulnerable(&"test", false)
	var archer := _director.spawn(ARCHER, Vector3(0, 0, 4))
	archer.brain.notice(_player, 0.0)
	var life := _player.health.current
	var hit := await _wait_until(func() -> bool: return _player.health.current < life, 6.0)
	assert_true(hit, "Pfeil trifft einen stehenden Spieler")
	var distance := archer.global_position.distance_to(_player.global_position)
	assert_gt(distance, ARCHER.keep_distance_min - 1.0, "hält Abstand: %.1f m" % distance)


func test_archer_retreats_when_player_is_close() -> void:
	var archer := _director.spawn(ARCHER, Vector3(0, 0, 10))
	archer.brain.notice(_player, 0.0)
	await wait_seconds(1.5)
	assert_gt(
		archer.global_position.distance_to(_player.global_position),
		3.0,
		"Bogenschütze weicht zurück"
	)


func test_cultist_summons_skeletons_up_to_the_limit() -> void:
	_player.health.set_invulnerable(&"test", true)
	var cultist := _director.spawn(CULTIST, Vector3(0, 0, 3))
	cultist.brain.notice(_player, 0.0)
	var summoned := await _wait_until(
		func() -> bool: return cultist.brain.get_summon_count() > 0, 5.0
	)
	assert_true(summoned, "Kultist beschwört")
	var summons := cultist.brain.get_summons()
	assert_eq(summons.size(), CULTIST.attacks[0].summon_count)
	for minion in summons:
		assert_eq(minion.type.id, &"skeleton")
		assert_true(minion.is_summon)
		assert_eq(minion.summoner, cultist)
	assert_lte(cultist.brain.get_summon_count(), CULTIST.attacks[0].summon_max_alive)


func test_death_drops_loot_and_awards_experience() -> void:
	var died: Array[Node3D] = []
	var xp: Array[int] = []
	var drops: Array[ItemInstance] = []
	var on_died := func(entity: Node3D, _killer: Node3D) -> void: died.append(entity)
	var on_xp := func(amount: int, _source: Node3D) -> void: xp.append(amount)
	var on_drop := func(item: ItemInstance, _pos: Vector3) -> void: drops.append(item)
	EventBus.entity_died.connect(on_died)
	EventBus.experience_awarded.connect(on_xp)
	EventBus.loot_dropped.connect(on_drop)
	var enemy := _director.spawn_with_affixes(GHOUL, Vector3(10, 0, -10), 2, _affix("fast"))
	_kill(enemy)
	EventBus.entity_died.disconnect(on_died)
	EventBus.experience_awarded.disconnect(on_xp)
	EventBus.loot_dropped.disconnect(on_drop)
	assert_eq(died, [enemy] as Array[Node3D], "entity_died genau einmal")
	var expected := roundi(
		GHOUL.experience_for_level(2) * EliteRules.get_default().experience_multiplier
	)
	assert_eq(xp, [expected] as Array[int], "Erfahrung mit Stufe und Elite-Bonus")
	assert_gt(drops.size(), 0, "Elite lässt mindestens einen Gegenstand fallen")
	var ground := _arena.get_node("Actors").get_children().filter(
		func(node: Node) -> bool: return node is GroundItem
	)
	assert_gt(ground.size(), 0, "Beute liegt in der Arena")


func test_summons_give_no_loot_or_experience() -> void:
	var xp: Array[int] = []
	var on_xp := func(amount: int, _source: Node3D) -> void: xp.append(amount)
	EventBus.experience_awarded.connect(on_xp)
	var minion := _director.pool.acquire(
		SKELETON, _arena.get_node("Actors"), Vector3(5, 0, -5), 1, [], true
	)
	_kill(minion)
	EventBus.experience_awarded.disconnect(on_xp)
	assert_true(xp.is_empty())


func test_pool_reuses_dead_enemies() -> void:
	var spawned: Array[Node3D] = []
	var on_spawn := func(entity: Node3D) -> void: spawned.append(entity)
	EventBus.entity_spawned.connect(on_spawn)
	var enemy := _director.spawn(SKELETON, Vector3(10, 0, -10))
	var created := _director.pool.created_count()
	_kill(enemy)
	assert_true(enemy.is_dead())
	assert_true(
		await _wait_until(func() -> bool: return not enemy.is_inside_tree(), 5.0),
		"Körper verschwindet nach dem Tod"
	)
	assert_eq(_director.pool.free_count(&"skeleton"), 1)
	var again := _director.spawn(SKELETON, Vector3(-10, 0, -10))
	EventBus.entity_spawned.disconnect(on_spawn)
	assert_eq(again, enemy, "gleiche Instanz wiederverwendet")
	assert_eq(_director.pool.created_count(), created, "keine neue Szene erzeugt")
	assert_false(again.is_dead())
	assert_eq(again.health.current, again.health.maximum)
	assert_eq(again.get_state(), AIBrain.State.IDLE)
	assert_eq(again.collision_layer, PhysicsLayers.ENEMY)
	assert_true(again.hurtbox.is_alive())
	assert_eq(spawned.size(), 2, "entity_spawned auch bei Wiederverwendung")


func test_health_bar_data_for_the_ui() -> void:
	var changes: Array[float] = []
	var on_health := func(entity: Node3D, current: float, _max: float) -> void:
		if entity is Enemy:
			changes.append(current)
	EventBus.entity_health_changed.connect(on_health)
	var enemy := _director.spawn_with_affixes(SKELETON, Vector3(10, 0, -10), 1, _affix("vampiric"))
	Combat.apply_damage(HitInfo.create(_player, enemy, 10.0))
	EventBus.entity_health_changed.disconnect(on_health)
	assert_true(enemy.is_in_group(Enemy.GROUP))
	assert_true(enemy.is_elite)
	assert_string_contains(enemy.display_name, "Vampirisch")
	assert_gt(enemy.get_health_bar_position().y, 1.5)
	assert_gt(changes.size(), 0, "entity_health_changed für Lebensbalken")


func test_elite_is_tougher_and_bigger() -> void:
	var normal := _director.spawn(SKELETON, Vector3(10, 0, -10))
	var elite := _director.spawn_with_affixes(SKELETON, Vector3(-10, 0, -10), 1, _affix("fast"))
	var rules := EliteRules.get_default()
	assert_almost_eq(elite.health.maximum, normal.health.maximum * rules.life_multiplier, 0.01)
	assert_gt(elite.model_root.scale.x, normal.model_root.scale.x)


func test_elite_fast_moves_and_attacks_faster() -> void:
	var normal := _director.spawn(SKELETON, Vector3(10, 0, -10))
	var fast := _director.spawn_with_affixes(SKELETON, Vector3(-10, 0, -10), 1, _affix("fast"))
	assert_gt(
		fast.stats.get_value(Enums.Stat.MOVE_SPEED), normal.stats.get_value(Enums.Stat.MOVE_SPEED)
	)
	assert_gt(fast.attack_speed_multiplier, 1.0)
	fast.global_position = Vector3(0, 0, 10.5)
	fast.brain.notice(_player, 0.0)
	await _wait_until(func() -> bool: return fast.get_state() == AIBrain.State.ATTACK, 3.0)
	assert_lt(fast.telegraph.duration, SKELETON.attacks[0].windup, "kürzere Vorwarnung")


func test_elite_shielding_protects_itself_and_the_group() -> void:
	var types: Array[EnemyType] = [GHOUL, SKELETON]
	var group := _director.spawn_types(types, Vector3(0, 0, 6))
	var leader := group[0]
	leader.setup(GHOUL, 1, _affix("shielding"))
	leader.group_id = group[1].group_id
	leader.brain.notice(_player, 0.0)
	group[1].brain.notice(_player, 0.0)
	var shielded := await _wait_until(func() -> bool: return leader.has_shield(), 8.0)
	assert_true(shielded, "Schild wird aktiv")
	assert_true(group[1].has_shield(), "Gruppenmitglied bekommt den Schild")
	var result := Combat.apply_damage(HitInfo.create(_player, leader, 50.0))
	assert_true(result.evaded, "Schild blockt Schaden")
	await wait_seconds(3.0)
	assert_false(leader.has_shield(), "Schild endet")


func test_elite_vampiric_heals_from_damage_dealt() -> void:
	var vampire := _director.spawn_with_affixes(GHOUL, Vector3(10, 0, -10), 1, _affix("vampiric"))
	vampire.health.take_damage(100.0)
	var life := vampire.health.current
	var hit := HitInfo.create(vampire, _player, 20.0)
	var result := Combat.apply_damage(hit)
	assert_gt(result.amount, 0.0)
	assert_almost_eq(
		vampire.health.current, life + result.amount * _affix("vampiric")[0].life_steal, 0.01
	)


func test_elite_teleporting_jumps_next_to_the_player() -> void:
	var teleporter := _director.spawn_with_affixes(
		GHOUL, Vector3(-10, 0, -8), 1, _affix("teleporting")
	)
	teleporter.brain.notice(_player, 0.0)
	var start := teleporter.global_position.distance_to(_player.global_position)
	var jumped := await _wait_until(
		func() -> bool:
			return teleporter.global_position.distance_to(_player.global_position) < 4.0,
		8.0
	)
	assert_true(jumped, "springt vom Start (%.1f m) zum Spieler" % start)


func test_elite_burning_creates_fire_and_sets_on_fire() -> void:
	_player.health.set_invulnerable(&"test", false)
	var burner := _director.spawn_with_affixes(SKELETON, Vector3(0, 0, 4), 1, _affix("burning"))
	burner.brain.notice(_player, 0.0)
	var patch_seen := await _wait_until(
		func() -> bool: return not get_tree().get_nodes_in_group(FirePatch.GROUP).is_empty(), 6.0
	)
	assert_true(patch_seen, "Feuerfläche erscheint")
	var burning := await _wait_until(
		func() -> bool: return _player.status_effects.has_effect(&"burn"), 8.0
	)
	assert_true(burning, "Spieler brennt")
