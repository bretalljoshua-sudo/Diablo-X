extends GutTest
## Schwierigkeitskurve (AP9): Gegnerstufe folgt dem Spieler mit Abstand und Grenzen je Ebene.

var curve: DifficultyCurve


func before_all() -> void:
	curve = DifficultyCurve.get_default()


func test_default_curve_is_loaded_from_data() -> void:
	assert_eq(curve.resource_path, DifficultyCurve.DEFAULT_PATH)
	assert_eq(curve.max_level, 10)


func test_first_level_starts_at_one() -> void:
	assert_eq(curve.enemy_level(1, 1), 1)
	assert_eq(curve.enemy_level(1, 4), 3, "Ebene 1 eine Stufe unter dem Spieler")


func test_minimum_levels_make_the_way_down_harder() -> void:
	assert_eq(curve.enemy_level(2, 1), 2)
	assert_eq(curve.enemy_level(3, 1), 3)
	assert_gt(curve.enemy_level(2, 3), curve.enemy_level(1, 3))


func test_levels_are_capped_at_ten() -> void:
	for depth in [1, 2, 3]:
		assert_eq(curve.enemy_level(depth, 30), 10, "Ebene %d" % depth)


func test_curve_rises_monotonically_up_to_level_ten() -> void:
	for depth in [1, 2, 3]:
		var previous := 0
		for player_level in range(1, 11):
			var level := curve.enemy_level(depth, player_level)
			assert_true(level >= previous, "Ebene %d, Stufe %d" % [depth, player_level])
			previous = level


func test_spawn_table_copies_the_ap3_table() -> void:
	var source := EnemyDirector.load_spawn_table(2)
	var table := curve.spawn_table_for(2, 5)
	assert_not_null(table)
	assert_eq(table.level, 5)
	assert_ne(table, source, "Kopie, das Original bleibt unverändert")
	assert_eq(table.groups.size(), source.groups.size())


func test_death_costs_a_tenth_of_the_gold() -> void:
	assert_almost_eq(curve.death_gold_loss, 0.1, 0.001)
