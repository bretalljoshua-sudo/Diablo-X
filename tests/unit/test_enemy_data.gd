extends GutTest
## Daten von AP3: Gegnertypen, Elite-Eigenschaften, Spawn-Tabellen, Vorwarnflächen.

const TYPE_PATHS := [
	"res://data/enemies/skeleton.tres",
	"res://data/enemies/ghoul.tres",
	"res://data/enemies/skeleton_archer.tres",
	"res://data/enemies/cultist.tres",
]


func _types() -> Array[EnemyType]:
	var types: Array[EnemyType] = []
	for path: String in TYPE_PATHS:
		types.append(load(path) as EnemyType)
	return types


func test_four_enemy_types_are_complete_enemy_defs() -> void:
	var ids: Array[StringName] = []
	for type in _types():
		assert_not_null(type)
		assert_true(type is EnemyDef, "EnemyType erfüllt den Vertrag EnemyDef")
		assert_ne(type.id, &"")
		assert_false(ids.has(type.id), "id eindeutig: %s" % type.id)
		ids.append(type.id)
		assert_ne(type.display_name, "")
		assert_not_null(type.scene, "%s hat eine Szene" % type.id)
		assert_not_null(type.loot_table, "%s hat eine Beutetabelle" % type.id)
		assert_gt(type.experience, 0)
		assert_false(type.attacks.is_empty(), "%s hat Angriffe" % type.id)
		assert_true(type.model_path.begins_with("res://assets/characters/"))
		assert_gt(type.base_stats.get_value(Enums.Stat.MAX_LIFE), 0.0)
		for attack in type.attacks:
			assert_gt(
				attack.windup, 0.29, "%s/%s hat eine sichtbare Vorwarnung" % [type.id, attack.id]
			)
			assert_gt(attack.cooldown, 0.0)
	assert_eq(ids, [&"skeleton", &"ghoul", &"skeleton_archer", &"cultist"])


func test_behaviors_cover_melee_ranged_and_summoner() -> void:
	var behaviors: Dictionary[StringName, bool] = {}
	for type in _types():
		behaviors[type.behavior] = true
	assert_true(behaviors.has(&"melee"))
	assert_true(behaviors.has(&"ranged"))
	assert_true(behaviors.has(&"summoner"))
	var cultist := load("res://data/enemies/cultist.tres") as EnemyType
	var summon := cultist.attacks[0]
	assert_eq(summon.kind, EnemyAttack.Kind.SUMMON)
	assert_eq((summon.summon_type as EnemyType).id, &"skeleton")


func test_stats_grow_with_level() -> void:
	var ghoul := load("res://data/enemies/ghoul.tres") as EnemyType
	var one := ghoul.stats_for_level(1)
	var five := ghoul.stats_for_level(5)
	assert_eq(one.get_value(Enums.Stat.MAX_LIFE), ghoul.base_stats.get_value(Enums.Stat.MAX_LIFE))
	assert_almost_eq(
		five.get_value(Enums.Stat.MAX_LIFE),
		(
			ghoul.base_stats.get_value(Enums.Stat.MAX_LIFE)
			+ 4 * ghoul.stats_per_level.get_value(Enums.Stat.MAX_LIFE)
		),
		0.001
	)
	assert_gt(five.get_value(Enums.Stat.DAMAGE), one.get_value(Enums.Stat.DAMAGE))
	assert_gt(ghoul.experience_for_level(5), ghoul.experience_for_level(1))


func test_elite_rules_have_five_distinct_affixes() -> void:
	var rules := EliteRules.get_default()
	assert_eq(rules.affixes.size(), 5)
	var kinds: Dictionary[EliteAffix.Kind, bool] = {}
	for affix in rules.affixes:
		assert_ne(affix.display_name, "")
		kinds[affix.kind] = true
	assert_eq(kinds.size(), 5, "schnell, brennend, schildtragend, teleportierend, vampirisch")
	assert_not_null(rules.loot_table)
	assert_gt(rules.life_multiplier, 1.0)
	var rng := Rng.make(3)
	for i in 50:
		var rolled := rules.roll_affixes(3, rng)
		assert_eq(rolled.size(), 3)
		assert_ne(rolled[0], rolled[1])
		assert_ne(rolled[1], rolled[2])
		assert_ne(rolled[0], rolled[2])
	assert_eq(rules.affix_count(1), 1)
	assert_eq(rules.affix_count(99), rules.affix_count_by_level[-1])


func test_spawn_tables_roll_groups_reproducibly() -> void:
	for depth in [1, 2]:
		var table := EnemyDirector.load_spawn_table(depth)
		assert_not_null(table, "Spawn-Tabelle für Ebene %d" % depth)
		assert_gt(table.groups.size(), 3)
		var a := Rng.make(11)
		var b := Rng.make(11)
		for i in 20:
			var group_a := table.pick_group(a)
			var group_b := table.pick_group(b)
			assert_eq(group_a, group_b)
			var members := group_a.roll_members(a)
			assert_eq(members, group_b.roll_members(b))
			assert_gt(members.size(), 0)
	assert_null(EnemyDirector.load_spawn_table(0), "Dorf ohne Gegner")


func test_group_member_counts_stay_in_range() -> void:
	var table := EnemyDirector.load_spawn_table(1)
	var rng := Rng.make(5)
	for group in table.groups:
		var low := 0
		var high := 0
		for member in group.members:
			low += member.count.x
			high += member.count.y
		for i in 30:
			var count := group.roll_members(rng).size()
			assert_between(count, low, high, "Gruppe %s" % group.id)


func test_formation_places_members_apart() -> void:
	var spots := EnemyDirector.formation(Vector3(3, 0, 4), 7, 1.6, 0.3)
	assert_eq(spots.size(), 7)
	assert_eq(spots[0], Vector3(3, 0, 4))
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			assert_gt(spots[i].distance_to(spots[j]), 1.0, "Abstand %d–%d" % [i, j])


func test_telegraph_shapes_contain_the_right_points() -> void:
	var telegraph := AttackTelegraph.new()
	add_child_autofree(telegraph)
	telegraph.show_circle(2.0, 1.0)
	assert_true(telegraph.contains_point(Vector3(1.5, 0, 0)))
	assert_false(telegraph.contains_point(Vector3(2.5, 0, 0)))
	assert_true(telegraph.contains_point(Vector3(2.3, 0, 0), 0.5), "Rand der Figur zählt")
	telegraph.show_cone(2.0, 90.0, 1.0)
	assert_true(telegraph.contains_point(Vector3(0, 0, -1.5)), "vorne im Kegel")
	assert_false(telegraph.contains_point(Vector3(0, 0, 1.5)), "hinten nicht")
	assert_false(telegraph.contains_point(Vector3(1.5, 0, -0.5)), "seitlich außerhalb")
	telegraph.show_line(10.0, 1.0, 1.0)
	assert_true(telegraph.contains_point(Vector3(0.3, 0, -8)))
	assert_false(telegraph.contains_point(Vector3(1.2, 0, -8)))
	assert_false(telegraph.contains_point(Vector3(0, 0, -11)))
	assert_true(telegraph.is_in_group(AttackTelegraph.GROUP))
	assert_almost_eq(telegraph.get_time_left(), 1.0, 0.001)
	telegraph.hide_telegraph()
	assert_false(telegraph.contains_point(Vector3(0.3, 0, -8)), "versteckt trifft nichts")
	assert_false(telegraph.is_in_group(AttackTelegraph.GROUP))


func test_populate_uses_every_spawn_point_of_a_generated_level() -> void:
	var layout := World.generate(1234, World.config_for_depth(1))
	assert_gt(layout.spawn_points.size(), 0)
	var director := EnemyDirector.new()
	var parent := Node3D.new()
	add_child_autofree(parent)
	director.actors_parent = parent
	parent.add_child(director)
	var table := EnemyDirector.load_spawn_table(1)
	var first := director.populate(layout, table, Rng.make(8))
	var positions: Array[Vector3] = []
	for enemy in first:
		positions.append(enemy.global_position)
	assert_gte(first.size(), layout.spawn_points.size(), "mindestens ein Gegner je Spawnpunkt")
	for enemy in first:
		assert_eq(enemy.level, table.level)
		assert_eq(enemy.get_parent(), parent)
	director.clear()
	assert_eq(director.get_enemies().size(), 0)
	var second := director.populate(layout, table, Rng.make(8))
	assert_eq(second.size(), first.size(), "gleicher Seed, gleiche Gegnerzahl")
	for i in second.size():
		assert_eq(second[i].global_position, positions[i])
