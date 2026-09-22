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
		"entity_health_changed",
		"experience_changed",
		"skill_tree_changed",
		"skill_slot_changed",
		"skill_cooldown_started",
		"skill_rank_up_requested",
		"skill_slot_assign_requested",
		"boss_encounter_started",
		"boss_encounter_ended",
		"merchant_opened",
		"merchant_item_bought",
		"merchant_item_sold",
		"ui_window_toggled",
	]
	for signal_name: String in expected:
		assert_true(EventBus.has_signal(signal_name), "EventBus.%s fehlt" % signal_name)


func test_physics_layers_match_project_settings() -> void:
	assert_eq(PhysicsLayers.WORLD, 1)
	assert_eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_2"), "player")
	assert_eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_3"), "enemy")
	assert_eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_4"), "hurtbox")
	assert_eq(PhysicsLayers.HURTBOX, 1 << 3)
	assert_eq(PhysicsLayers.LOOT, 1 << 4)


func test_level_layout_ap6_fields_survive_save_and_load() -> void:
	var layout := LevelLayout.new()
	layout.depth = 2
	layout.props[Vector3i(3, 0, 4)] = 20
	layout.rooms.append(Rect2i(0, 0, 5, 6))
	layout.room_links.append(Vector2i(0, 1))
	layout.markers[&"boss_spawn"] = Vector3(8, 0, 8)
	var path := "user://test_layout_ap6.tres"
	assert_eq(ResourceSaver.save(layout, path), OK)
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelLayout
	assert_eq(loaded.depth, 2)
	assert_eq(loaded.props[Vector3i(3, 0, 4)], 20)
	assert_eq(loaded.rooms[0], Rect2i(0, 0, 5, 6))
	assert_eq(loaded.room_links[0], Vector2i(0, 1))
	assert_eq(loaded.markers[&"boss_spawn"], Vector3(8, 0, 8))
	assert_eq(loaded.entrance, Vector3.INF, "Standard: kein Rückweg")


func test_skill_tree_state_rules() -> void:
	var skill := SkillDef.new()
	skill.id = &"strike"
	var state := SkillTreeState.new()
	state.skills.append(skill)
	assert_eq(state.get_rank(skill), 0)
	assert_eq(state.get_max_rank(skill), SkillTreeState.DEFAULT_MAX_RANK)
	assert_false(state.can_rank_up(skill), "ohne Punkte und gesperrt")
	state.points = 1
	assert_false(state.can_rank_up(skill), "gesperrt")
	state.unlocked.append(&"strike")
	assert_true(state.can_rank_up(skill))
	state.max_ranks[&"strike"] = 1
	state.ranks[&"strike"] = 1
	assert_false(state.can_rank_up(skill), "höchster Rang erreicht")
	assert_eq(state.find_skill(&"strike"), skill)


func test_settings_key_binding_roundtrip() -> void:
	var before := Settings.get_key_binding(&"open_inventory")
	Settings.set_key_binding(&"open_inventory", KEY_B)
	assert_eq(Settings.get_key_binding(&"open_inventory"), KEY_B)
	Settings.reset_key_bindings()
	assert_eq(Settings.get_key_binding(&"open_inventory"), before)
	assert_eq(before, KEY_I)
