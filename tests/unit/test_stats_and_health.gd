extends GutTest
## StatsComponent, Stats-Dienst und HealthComponent (AP2).

const Entity := preload("res://tests/unit/ap2_entity.gd")


func _make(stats: Dictionary = {}) -> Node3D:
	return add_child_autofree(Entity.make(stats)) as Node3D


func test_missing_stats_use_defaults() -> void:
	var entity := _make({Enums.Stat.MAX_LIFE: 80.0})
	assert_eq(Stats.get_stat(entity, Enums.Stat.MAX_LIFE), 80.0)
	assert_eq(
		Stats.get_stat(entity, Enums.Stat.MOVE_SPEED),
		StatDefaults.get_default(Enums.Stat.MOVE_SPEED)
	)


func test_flat_and_percent_sources_combine() -> void:
	var entity := _make({Enums.Stat.DAMAGE: 10.0})
	var component := Components.stats(entity)
	component.set_flat_source(&"weapon", StatBlock.from_dict({Enums.Stat.DAMAGE: 5.0}))
	component.set_flat_source(&"ring", StatBlock.from_dict({Enums.Stat.DAMAGE: 5.0}))
	component.set_percent_source(&"shout", StatBlock.from_dict({Enums.Stat.DAMAGE: 0.5}))
	component.set_percent_source(&"curse", StatBlock.from_dict({Enums.Stat.DAMAGE: -0.25}))
	assert_almost_eq(Stats.get_stat(entity, Enums.Stat.DAMAGE), 25.0, 0.001, "(10+5+5) × 1,25")
	component.remove_source(&"ring")
	component.set_percent_source(&"shout", null)
	assert_almost_eq(Stats.get_stat(entity, Enums.Stat.DAMAGE), 11.25, 0.001, "(10+5) × 0,75")


func test_percent_sources_never_go_below_zero() -> void:
	var entity := _make({Enums.Stat.MOVE_SPEED: 6.0})
	var block := StatBlock.from_dict({Enums.Stat.MOVE_SPEED: -3.0})
	Stats.set_percent_source(entity, &"root", block)
	assert_eq(Stats.get_stat(entity, Enums.Stat.MOVE_SPEED), 0.0)


func test_source_is_copied() -> void:
	var entity := _make({Enums.Stat.ARMOR: 0.0})
	var block := StatBlock.from_dict({Enums.Stat.ARMOR: 10.0})
	Stats.set_flat_source(entity, &"helm", block)
	block.set_value(Enums.Stat.ARMOR, 999.0)
	assert_eq(Stats.get_stat(entity, Enums.Stat.ARMOR), 10.0)


func test_stats_changed_is_emitted() -> void:
	var entity := _make()
	var component := Components.stats(entity)
	watch_signals(component)
	component.set_flat_source(&"x", StatBlock.from_dict({Enums.Stat.ARMOR: 1.0}))
	assert_signal_emitted(component, "stats_changed")


func test_player_equipped_sets_equipment_source_on_player() -> void:
	var player := _make({Enums.Stat.DAMAGE: 10.0})
	var previous := Game.player
	Game.player = player
	var base := ItemBase.new()
	base.base_stats = StatBlock.from_dict({Enums.Stat.DAMAGE: 7.0})
	var item := ItemInstance.new()
	item.base = base
	EventBus.player_equipped.emit(Enums.Slot.WEAPON, item)
	assert_eq(Stats.get_stat(player, Enums.Stat.DAMAGE), 17.0)
	assert_true(Components.stats(player).has_source(&"equipment:weapon"))
	EventBus.player_equipped.emit(Enums.Slot.WEAPON, null)
	assert_eq(Stats.get_stat(player, Enums.Stat.DAMAGE), 10.0, "Ablegen nimmt die Werte weg")
	Game.player = previous


func test_health_starts_full_from_max_life() -> void:
	var entity := _make({Enums.Stat.MAX_LIFE: 120.0})
	var health := Components.health(entity)
	assert_eq(health.maximum, 120.0)
	assert_eq(health.current, 120.0)


func test_heal_is_clamped_and_reports_amount() -> void:
	var health := Components.health(_make({Enums.Stat.MAX_LIFE: 100.0}))
	health.take_damage(30.0)
	assert_eq(health.heal(50.0), 30.0)
	assert_eq(health.current, 100.0)
	assert_eq(health.heal(10.0), 0.0)


func test_death_and_revive() -> void:
	var health := Components.health(_make({Enums.Stat.MAX_LIFE: 100.0}))
	watch_signals(health)
	assert_true(health.take_damage(150.0))
	assert_true(health.is_dead())
	assert_eq(health.current, 0.0)
	assert_false(health.take_damage(10.0), "Tote sterben nicht zweimal")
	assert_eq(health.heal(10.0), 0.0, "Tote werden nicht geheilt")
	assert_signal_emit_count(health, "died", 1)
	health.revive(0.5)
	assert_false(health.is_dead())
	assert_eq(health.current, 50.0)


func test_max_life_change_keeps_ratio() -> void:
	var entity := _make({Enums.Stat.MAX_LIFE: 100.0})
	var health := Components.health(entity)
	health.take_damage(50.0)
	Stats.set_flat_source(entity, &"amulet", StatBlock.from_dict({Enums.Stat.MAX_LIFE: 100.0}))
	assert_eq(health.maximum, 200.0)
	assert_eq(health.current, 100.0)


func test_invulnerability_reasons_stack() -> void:
	var health := Components.health(_make())
	health.set_invulnerable(&"dodge", true)
	health.set_invulnerable(&"cutscene", true)
	health.set_invulnerable(&"dodge", false)
	assert_true(health.is_invulnerable())
	health.set_invulnerable(&"cutscene", false)
	assert_false(health.is_invulnerable())


func test_ap0_stats_property_still_works() -> void:
	var holder: Node = autofree(preload("res://tests/unit/stats_holder.gd").new())
	holder.set("stats", StatBlock.from_dict({Enums.Stat.ARMOR: 33.0}))
	assert_eq(Stats.get_stat(holder, Enums.Stat.ARMOR), 33.0)
	assert_eq(Stats.get_stat(null, Enums.Stat.ARMOR), 0.0)
