extends SimTest
## Gegner in echten Ebenen aus AP6: Der EnemyDirector füllt jede geladene Ebene, alle Gegner
## stehen auf dem Navigationsnetz, und beim Ebenenwechsel werden sie weggeräumt.


func before_each() -> void:
	Combat.hit_stop_enabled = false
	Rng.set_master_seed(31337)


func after_each() -> void:
	Combat.hit_stop_enabled = true


func test_director_populates_generated_level_on_navmesh() -> void:
	var scene: Node3D = await load_scene("enemy_dungeon")
	var level: Level = scene.get("level")
	var director: EnemyDirector = scene.get("director")
	await wait_physics_frames(10)
	var layout := level.layout
	assert_not_null(layout)
	var enemies := director.get_alive()
	assert_gte(enemies.size(), layout.spawn_points.size(), "jede Gruppe erschienen")
	var map := level.get_world_3d().navigation_map
	for enemy in enemies:
		assert_eq(enemy.get_parent(), level.actors, "Gegner hängen unter Level.actors")
		var closest := NavigationServer3D.map_get_closest_point(map, enemy.global_position)
		var off := Vector2(closest.x - enemy.global_position.x, closest.z - enemy.global_position.z)
		assert_lt(
			off.length(),
			0.6,
			"%s steht auf dem Netz: %s → %s" % [enemy.display_name, enemy.global_position, closest]
		)
	var player := level.player as Player
	assert_not_null(player)
	for enemy in enemies:
		assert_gt(
			enemy.global_position.distance_to(player.global_position),
			4.0,
			"kein Gegner direkt am Start"
		)


func test_enemies_stay_on_their_floor_while_fighting() -> void:
	var scene: Node3D = await load_scene("enemy_dungeon")
	var level: Level = scene.get("level")
	var director: EnemyDirector = scene.get("director")
	await wait_physics_frames(10)
	var player := level.player as Player
	player.input_enabled = false
	player.health.set_invulnerable(&"test", true)
	var enemies := director.get_alive()
	# Spieler neben die erste Gruppe stellen (auf dem Netz), damit sie in Reichweite ist.
	var map := level.get_world_3d().navigation_map
	var near := NavigationServer3D.map_get_closest_point(
		map, enemies[0].global_position + Vector3(5, 0, 0)
	)
	player.global_position = near
	player.stop()
	await wait_physics_frames(2)
	var heights: Dictionary[Enemy, float] = {}
	var chasing: Array[Enemy] = []
	for enemy in enemies:
		heights[enemy] = enemy.global_position.y
		if enemy.global_position.distance_to(player.global_position) < 20.0:
			enemy.brain.notice(player, 0.0)
			chasing.append(enemy)
	await wait_seconds(2.0)
	var moved := 0
	for enemy in enemies:
		if not enemy.is_active():
			continue
		assert_almost_eq(enemy.global_position.y, heights[enemy], 0.05, "bleibt auf dem Boden")
	for enemy in chasing:
		if enemy.is_active() and enemy.get_state() != AIBrain.State.IDLE:
			moved += 1
	assert_gt(moved, 0, "Gegner verfolgen den Spieler durch den Dungeon")


func test_level_change_clears_and_repopulates() -> void:
	var scene: Node3D = await load_scene("enemy_dungeon")
	var level: Level = scene.get("level")
	var director: EnemyDirector = scene.get("director")
	await wait_physics_frames(10)
	var first := director.get_alive()
	assert_gt(first.size(), 0)
	level.load_depth(2, 1)
	await wait_physics_frames(10)
	for enemy in first:
		assert_true(
			(
				not is_instance_valid(enemy)
				or not enemy.is_inside_tree()
				or enemy in director.get_alive()
			),
			"alte Gegner weggeräumt oder wiederverwendet"
		)
	var second := director.get_alive()
	assert_gte(second.size(), level.layout.spawn_points.size())
	var table := EnemyDirector.load_spawn_table(2)
	for enemy in second:
		assert_eq(enemy.level, table.level, "Stufe der Ebene 2")
