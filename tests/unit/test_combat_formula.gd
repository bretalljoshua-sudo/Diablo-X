extends GutTest
## Schadensformel von Combat.apply_damage() (AP2): Rüstung, Resistenzen, kritische Treffer,
## Unverwundbarkeit, Tod, Leben bei Treffer und Rückstoß.

const Entity := preload("res://tests/unit/ap2_entity.gd")


func _make(stats: Dictionary = {}) -> Node3D:
	return add_child_autofree(Entity.make(stats)) as Node3D


func _hit(
	source: Node3D, target: Node3D, base: float, type := Enums.DamageType.PHYSICAL
) -> HitInfo:
	var hit := HitInfo.create(source, target, base, type)
	return hit


func test_physical_damage_without_armor_is_base() -> void:
	var source := _make({Enums.Stat.CRIT_CHANCE: 0.0})
	var target := _make({Enums.Stat.MAX_LIFE: 100.0})
	var result := Combat.apply_damage(_hit(source, target, 30.0))
	assert_almost_eq(result.amount, 30.0, 0.001)
	assert_almost_eq(Components.health(target).current, 70.0, 0.001)
	assert_false(result.crit)
	assert_false(result.killed)


func test_armor_reduces_physical_damage() -> void:
	var constant := Combat.config.armor_constant
	var source := _make({Enums.Stat.CRIT_CHANCE: 0.0})
	# Rüstung = Konstante ergibt genau 50 % Minderung.
	var target := _make({Enums.Stat.MAX_LIFE: 1000.0, Enums.Stat.ARMOR: constant})
	var result := Combat.apply_damage(_hit(source, target, 100.0))
	assert_almost_eq(result.amount, 50.0, 0.001)


func test_armor_reduction_is_capped() -> void:
	assert_eq(Combat.armor_reduction(0.0), 0.0)
	assert_eq(Combat.armor_reduction(-50.0), 0.0)
	assert_almost_eq(Combat.armor_reduction(1.0e9), Combat.config.max_armor_reduction, 0.0001)


func test_armor_does_not_reduce_fire_damage() -> void:
	var source := _make({Enums.Stat.CRIT_CHANCE: 0.0})
	var target := _make({Enums.Stat.MAX_LIFE: 1000.0, Enums.Stat.ARMOR: 5000.0})
	var result := Combat.apply_damage(_hit(source, target, 40.0, Enums.DamageType.FIRE))
	assert_almost_eq(result.amount, 40.0, 0.001)


func test_resistance_reduces_matching_type_and_is_capped() -> void:
	var source := _make({Enums.Stat.CRIT_CHANCE: 0.0})
	var target := _make({Enums.Stat.MAX_LIFE: 1000.0, Enums.Stat.FIRE_RESIST: 0.3})
	var fire := Combat.apply_damage(_hit(source, target, 100.0, Enums.DamageType.FIRE))
	assert_almost_eq(fire.amount, 70.0, 0.001, "30 % Feuerresistenz")
	var cold := Combat.apply_damage(_hit(source, target, 100.0, Enums.DamageType.COLD))
	assert_almost_eq(cold.amount, 100.0, 0.001, "Feuerresistenz hilft nicht gegen Kälte")
	var capped := _make({Enums.Stat.MAX_LIFE: 1000.0, Enums.Stat.POISON_RESIST: 5.0})
	var poison := Combat.apply_damage(_hit(source, capped, 100.0, Enums.DamageType.POISON))
	assert_almost_eq(poison.amount, 100.0 * (1.0 - Combat.config.max_resist), 0.001)


func test_negative_resistance_increases_damage() -> void:
	var source := _make({Enums.Stat.CRIT_CHANCE: 0.0})
	var target := _make({Enums.Stat.MAX_LIFE: 1000.0, Enums.Stat.COLD_RESIST: -0.5})
	var result := Combat.apply_damage(_hit(source, target, 100.0, Enums.DamageType.COLD))
	assert_almost_eq(result.amount, 150.0, 0.001)


func test_guaranteed_crit_multiplies_damage() -> void:
	var source := _make({Enums.Stat.CRIT_CHANCE: 1.0, Enums.Stat.CRIT_DAMAGE: 0.75})
	var target := _make({Enums.Stat.MAX_LIFE: 1000.0})
	var result := Combat.apply_damage(_hit(source, target, 40.0))
	assert_true(result.crit)
	assert_almost_eq(result.amount, 70.0, 0.001)


func test_crit_applies_before_armor() -> void:
	var source := _make({Enums.Stat.CRIT_CHANCE: 1.0, Enums.Stat.CRIT_DAMAGE: 1.0})
	var target := _make(
		{Enums.Stat.MAX_LIFE: 1000.0, Enums.Stat.ARMOR: Combat.config.armor_constant}
	)
	var result := Combat.apply_damage(_hit(source, target, 50.0))
	assert_almost_eq(result.amount, 50.0, 0.001, "50 × 2 (kritisch) × 0,5 (Rüstung)")


func test_can_crit_false_never_crits() -> void:
	var source := _make({Enums.Stat.CRIT_CHANCE: 1.0})
	var target := _make({Enums.Stat.MAX_LIFE: 1000.0})
	var hit := _hit(source, target, 10.0)
	hit.can_crit = false
	assert_false(Combat.apply_damage(hit).crit)


func test_crit_rate_matches_chance() -> void:
	Combat.set_rng(Rng.make(1234))
	var source := _make({Enums.Stat.CRIT_CHANCE: 0.25})
	var target := _make({Enums.Stat.MAX_LIFE: 1.0e9})
	var crits := 0
	for i in 2000:
		if Combat.apply_damage(_hit(source, target, 1.0)).crit:
			crits += 1
	assert_between(crits, 420, 580, "rund 25 % von 2000")
	Combat.set_rng(Rng.stream(&"combat"))


func test_kill_emits_died_once_and_dead_targets_ignore_hits() -> void:
	var source := _make({Enums.Stat.CRIT_CHANCE: 0.0})
	var target := _make({Enums.Stat.MAX_LIFE: 50.0})
	watch_signals(EventBus)
	var result := Combat.apply_damage(_hit(source, target, 80.0))
	assert_true(result.killed)
	assert_true(Components.health(target).is_dead())
	assert_signal_emit_count(EventBus, "entity_died", 1)
	assert_signal_emitted_with_parameters(EventBus, "entity_died", [target, source])
	var again := Combat.apply_damage(_hit(source, target, 80.0))
	assert_eq(again.amount, 0.0)
	assert_false(again.killed)
	assert_signal_emit_count(EventBus, "entity_died", 1, "kein zweiter Tod")


func test_invulnerable_target_evades() -> void:
	var source := _make({Enums.Stat.CRIT_CHANCE: 0.0})
	var target := _make({Enums.Stat.MAX_LIFE: 50.0})
	Components.health(target).set_invulnerable(&"dodge", true)
	watch_signals(EventBus)
	var result := Combat.apply_damage(_hit(source, target, 30.0))
	assert_true(result.evaded)
	assert_eq(result.amount, 0.0)
	assert_eq(Components.health(target).current, 50.0)
	assert_signal_not_emitted(EventBus, "damage_dealt")
	Components.health(target).set_invulnerable(&"dodge", false)
	assert_false(Combat.apply_damage(_hit(source, target, 30.0)).evaded)


func test_life_on_hit_heals_source() -> void:
	var source := _make({Enums.Stat.CRIT_CHANCE: 0.0, Enums.Stat.LIFE_ON_HIT: 5.0})
	var source_health := Components.health(source)
	source_health.take_damage(20.0)
	var target := _make({Enums.Stat.MAX_LIFE: 100.0})
	Combat.apply_damage(_hit(source, target, 10.0))
	assert_almost_eq(source_health.current, 85.0, 0.001)


func test_knockback_pushes_target_away_from_source() -> void:
	var source := _make({Enums.Stat.CRIT_CHANCE: 0.0})
	var target := _make({Enums.Stat.MAX_LIFE: 100.0})
	target.position = Vector3(2, 0, 0)
	var hit := _hit(source, target, 5.0)
	hit.knockback = 1.5
	Combat.apply_damage(hit)
	var knockback := Components.knockback(target)
	assert_true(knockback.is_active())
	var travelled := Vector3.ZERO
	for i in 60:
		travelled += knockback.consume(1.0 / 60.0) / 60.0
	assert_gt(travelled.x, 1.2, "rund 1,5 m nach +X")
	assert_lt(travelled.x, 1.8)
	assert_almost_eq(travelled.z, 0.0, 0.001)


func test_damage_dealt_carries_hit_and_result() -> void:
	var source := _make({Enums.Stat.CRIT_CHANCE: 0.0})
	var target := _make({Enums.Stat.MAX_LIFE: 100.0})
	watch_signals(EventBus)
	var hit := _hit(source, target, 12.0)
	var result := Combat.apply_damage(hit)
	assert_signal_emitted_with_parameters(EventBus, "damage_dealt", [hit, result])


func test_hit_stop_restores_time_scale() -> void:
	Combat.hit_stop(0.05)
	assert_lt(Engine.time_scale, 1.0)
	await wait_seconds(0.3)
	assert_eq(Engine.time_scale, 1.0)
	assert_false(Combat.is_hit_stop_active())
