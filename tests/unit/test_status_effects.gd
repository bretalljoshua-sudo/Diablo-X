extends GutTest
## Statuseffekte Verlangsamung, Brennen, Betäubung (AP2).

const Entity := preload("res://tests/unit/ap2_entity.gd")


func _make(stats: Dictionary = {}) -> Node3D:
	var entity := add_child_autofree(Entity.make(stats)) as Node3D
	# Tests treiben die Zeit selbst über tick().
	Components.status_effects(entity).set_physics_process(false)
	return entity


func test_slow_reduces_move_speed_and_expires() -> void:
	var entity := _make({Enums.Stat.MOVE_SPEED: 6.0})
	var effects := Components.status_effects(entity)
	assert_true(effects.apply(StatusEffectDef.create(&"slow", StatusEffectDef.Kind.SLOW, 2.0, 0.5)))
	assert_almost_eq(Stats.get_stat(entity, Enums.Stat.MOVE_SPEED), 3.0, 0.001)
	effects.tick(1.9)
	assert_true(effects.has_effect(&"slow"))
	effects.tick(0.2)
	assert_false(effects.has_effect(&"slow"))
	assert_almost_eq(Stats.get_stat(entity, Enums.Stat.MOVE_SPEED), 6.0, 0.001)


func test_strongest_slow_wins() -> void:
	var entity := _make({Enums.Stat.MOVE_SPEED: 10.0})
	var effects := Components.status_effects(entity)
	effects.apply(StatusEffectDef.create(&"chill", StatusEffectDef.Kind.SLOW, 3.0, 0.2))
	effects.apply(StatusEffectDef.create(&"web", StatusEffectDef.Kind.SLOW, 1.0, 0.6))
	assert_almost_eq(Stats.get_stat(entity, Enums.Stat.MOVE_SPEED), 4.0, 0.001, "60 % gewinnt")
	effects.tick(1.5)
	assert_almost_eq(Stats.get_stat(entity, Enums.Stat.MOVE_SPEED), 8.0, 0.001, "danach 20 %")


func test_reapply_refreshes_duration_without_stacking() -> void:
	var entity := _make()
	var effects := Components.status_effects(entity)
	var def := StatusEffectDef.create(&"slow", StatusEffectDef.Kind.SLOW, 2.0, 0.3)
	watch_signals(effects)
	effects.apply(def)
	effects.tick(1.5)
	effects.apply(def)
	assert_almost_eq(effects.get_time_left(&"slow"), 2.0, 0.001)
	assert_signal_emit_count(effects, "effect_started", 1)


func test_burn_deals_fire_damage_over_time() -> void:
	var entity := _make({Enums.Stat.MAX_LIFE: 100.0})
	var effects := Components.status_effects(entity)
	var burn := StatusEffectDef.create(&"burn", StatusEffectDef.Kind.BURN, 2.0, 10.0)
	burn.tick_interval = 0.5
	watch_signals(EventBus)
	effects.apply(burn)
	for i in 30:
		effects.tick(0.1)
	var health := Components.health(entity)
	assert_almost_eq(health.current, 80.0, 0.001, "10 pro Sekunde für 2 Sekunden")
	assert_signal_emit_count(EventBus, "damage_dealt", 4, "4 Takte zu je 0,5 s")
	assert_false(effects.has_effect(&"burn"))


func test_burn_respects_fire_resistance() -> void:
	var entity := _make({Enums.Stat.MAX_LIFE: 100.0, Enums.Stat.FIRE_RESIST: 0.5})
	var effects := Components.status_effects(entity)
	effects.apply(StatusEffectDef.create(&"burn", StatusEffectDef.Kind.BURN, 2.0, 10.0))
	effects.tick(1.0)
	effects.tick(1.0)
	assert_almost_eq(Components.health(entity).current, 90.0, 0.001)


func test_burn_kill_credits_source() -> void:
	var source := _make()
	var entity := _make({Enums.Stat.MAX_LIFE: 5.0})
	watch_signals(EventBus)
	Components.status_effects(entity).apply(
		StatusEffectDef.create(&"burn", StatusEffectDef.Kind.BURN, 3.0, 20.0), source
	)
	Components.status_effects(entity).tick(0.5)
	assert_true(Components.health(entity).is_dead())
	assert_signal_emitted_with_parameters(EventBus, "entity_died", [entity, source])
	assert_true(
		Components.status_effects(entity).get_active_ids().is_empty(), "Tod beendet Effekte"
	)


func test_stun_sets_flag_and_ends() -> void:
	var entity := _make()
	var effects := Components.status_effects(entity)
	effects.apply(StatusEffectDef.create(&"stun", StatusEffectDef.Kind.STUN, 1.0))
	assert_true(effects.is_stunned())
	assert_true(Components.is_stunned(entity))
	effects.tick(1.01)
	assert_false(effects.is_stunned())


func test_invulnerable_targets_get_no_effects() -> void:
	var entity := _make()
	Components.health(entity).set_invulnerable(&"dodge", true)
	var effects := Components.status_effects(entity)
	assert_false(effects.apply(StatusEffectDef.create(&"stun", StatusEffectDef.Kind.STUN, 1.0)))
	assert_false(effects.is_stunned())


func test_status_effect_changed_signal() -> void:
	var entity := _make()
	watch_signals(EventBus)
	var effects := Components.status_effects(entity)
	effects.apply(StatusEffectDef.create(&"slow", StatusEffectDef.Kind.SLOW, 0.5, 0.3))
	assert_signal_emitted_with_parameters(
		EventBus, "status_effect_changed", [entity, &"slow", true]
	)
	effects.tick(1.0)
	assert_signal_emitted_with_parameters(
		EventBus, "status_effect_changed", [entity, &"slow", false]
	)


func test_data_files_load() -> void:
	for effect_name in ["slow", "burn", "stun"]:
		var def := load("res://data/status_effects/%s.tres" % effect_name) as StatusEffectDef
		assert_not_null(def, effect_name)
		assert_eq(def.id, StringName(effect_name))
		assert_gt(def.duration, 0.0)
