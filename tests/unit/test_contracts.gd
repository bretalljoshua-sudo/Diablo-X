extends GutTest
## Prüft die Verträge aus scripts/contracts/. Schlägt ein Test fehl, hat jemand einen
## Vertrag geändert, auf den sich andere Pakete verlassen.


func test_enums_keep_their_order() -> void:
	# Die Zahlenwerte stehen in .tres-Dateien, deshalb darf sich die Reihenfolge nie ändern.
	assert_eq(Enums.Stat.MAX_LIFE, 0)
	assert_eq(Enums.Stat.POISON_RESIST, 13)
	assert_eq(Enums.Slot.RING_2, 8)
	assert_eq(Enums.Rarity.UNIQUE, 4)
	assert_eq(Enums.Targeting.CHANNEL, 5)


func test_hit_info_create() -> void:
	var hit := HitInfo.create(null, null, 12.5, Enums.DamageType.FIRE)
	assert_eq(hit.base, 12.5)
	assert_eq(hit.type, Enums.DamageType.FIRE)
	assert_true(hit.can_crit)


func test_stat_block_add_and_plus() -> void:
	var a := StatBlock.from_dict({Enums.Stat.DAMAGE: 10.0, Enums.Stat.ARMOR: 5.0})
	var b := StatBlock.from_dict({Enums.Stat.DAMAGE: 2.5})
	var sum := a.plus(b)
	assert_eq(sum.get_value(Enums.Stat.DAMAGE), 12.5)
	assert_eq(sum.get_value(Enums.Stat.ARMOR), 5.0)
	assert_eq(a.get_value(Enums.Stat.DAMAGE), 10.0, "plus() verändert den Ausgangsblock nicht")
	a.add(b)
	assert_eq(a.get_value(Enums.Stat.DAMAGE), 12.5)
	assert_eq(a.get_value(Enums.Stat.CRIT_CHANCE, 0.3), 0.3, "Standardwert für fehlende Stats")


func test_item_instance_sums_base_and_affixes() -> void:
	var base := ItemBase.new()
	base.display_name = "Rostiges Schwert"
	base.base_stats = StatBlock.from_dict({Enums.Stat.DAMAGE: 8.0})
	var affix := AffixDef.new()
	affix.stat = Enums.Stat.DAMAGE
	var roll := AffixRoll.new()
	roll.affix = affix
	roll.value = 3.0
	var item := ItemInstance.new()
	item.base = base
	item.affixes.append(roll)
	assert_eq(item.get_stats().get_value(Enums.Stat.DAMAGE), 11.0)
	assert_eq(item.get_display_name(), "Rostiges Schwert")


func test_resources_survive_save_and_load() -> void:
	var layout := LevelLayout.new()
	layout.seed = 42
	layout.cells[Vector3i(1, 0, 2)] = 3
	layout.spawn_points.append(Vector3(1, 0, 1))
	var path := "user://test_layout.tres"
	assert_eq(ResourceSaver.save(layout, path), OK)
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelLayout
	assert_eq(loaded.seed, 42)
	assert_eq(loaded.cells[Vector3i(1, 0, 2)], 3)
	assert_eq(loaded.spawn_points.size(), 1)
	DirAccess.remove_absolute(path)


func test_event_bus_has_all_contract_signals() -> void:
	var expected := [
		"damage_dealt",
		"entity_died",
		"entity_spawned",
		"loot_dropped",
		"loot_picked_up",
		"gold_changed",
		"skill_cast",
		"resource_changed",
		"player_level_up",
		"player_equipped",
		"level_loaded",
		"boss_phase_changed",
		"run_completed",
		"player_health_changed",
		"potion_charges_changed",
		"status_effect_changed",
		"hovered_target_changed",
	]
	for signal_name: String in expected:
		assert_true(EventBus.has_signal(signal_name), "EventBus.%s fehlt" % signal_name)


func test_physics_layers_match_project_settings() -> void:
	assert_eq(PhysicsLayers.WORLD, 1)
	assert_eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_2"), "player")
	assert_eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_3"), "enemy")
	assert_eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_4"), "hurtbox")
	assert_eq(PhysicsLayers.HURTBOX, 1 << 3)
