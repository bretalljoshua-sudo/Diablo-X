extends GutTest
## Prüft die Signaturen der Dienste Combat, Stats, Loot und World.
## Die Ersatzversionen aus AP0 und die späteren echten Versionen müssen diese Tests bestehen.

const StatsHolder := preload("res://tests/unit/stats_holder.gd")


class Dummy:
	extends Node3D
	var life: float = 20.0

	func take_damage(amount: float) -> bool:
		life -= amount
		return life <= 0.0


func test_combat_apply_damage_returns_result_and_emits() -> void:
	var target: Dummy = add_child_autofree(Dummy.new())
	watch_signals(EventBus)
	var result := Combat.apply_damage(HitInfo.create(null, target, 5.0))
	assert_true(result is DamageResult)
	assert_gt(result.amount, 0.0)
	assert_false(result.killed)
	assert_signal_emitted(EventBus, "damage_dealt")
	assert_signal_not_emitted(EventBus, "entity_died")


func test_combat_kill_emits_entity_died() -> void:
	var target: Dummy = add_child_autofree(Dummy.new())
	watch_signals(EventBus)
	var result := Combat.apply_damage(HitInfo.create(null, target, 1000.0))
	assert_true(result.killed)
	assert_signal_emitted(EventBus, "entity_died")


func test_combat_ignores_missing_target() -> void:
	var result := Combat.apply_damage(HitInfo.create(null, null, 5.0))
	assert_eq(result.amount, 0.0)


func test_stats_get_stat_uses_entity_stats() -> void:
	var entity := autofree(Node3D.new()) as Node3D
	assert_gt(Stats.get_stat(entity, Enums.Stat.MAX_LIFE), 0.0, "Grundwert ohne StatBlock")
	var holder: Node = autofree(StatsHolder.new())
	holder.set("stats", StatBlock.from_dict({Enums.Stat.MAX_LIFE: 250.0}))
	assert_eq(Stats.get_stat(holder, Enums.Stat.MAX_LIFE), 250.0)


func test_loot_roll_drop_returns_items() -> void:
	var drops := Loot.roll_drop(LootTable.new(), 3, Rng.make(1))
	assert_eq(drops.size(), 1)
	assert_true(drops[0] is ItemInstance)
	assert_eq(drops[0].item_level, 3)
	assert_not_null(drops[0].base)


func test_loot_is_reproducible_with_same_seed() -> void:
	var a := Loot.roll_drop(null, 1, Rng.make(99))
	var b := Loot.roll_drop(null, 1, Rng.make(99))
	assert_eq(a[0].uid, b[0].uid)


func test_world_generate_is_deterministic() -> void:
	var config := LevelConfig.new()
	var a := World.generate(7, config)
	var b := World.generate(7, config)
	assert_true(a is LevelLayout)
	assert_eq(a.seed, 7)
	assert_eq(a.cells, b.cells)
	assert_eq(a.spawn_points, b.spawn_points)
	assert_true(a.bounds.has_point(a.player_start + Vector3(0, 0.1, 0)))
	assert_false(a.spawn_points.is_empty())
