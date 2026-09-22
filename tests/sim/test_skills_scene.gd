extends SkillsSimTest
## Simulationstests für die AP5-Testszene skills_test: jeder der sieben Skills, Stufenaufstieg,
## Abbruch durch die Ausweichrolle, Eingaben und Fehlschläge.

# --- Skills --------------------------------------------------------------------------------


func test_scene_starts_with_all_skills_learned_and_on_the_bar() -> void:
	assert_not_null(_skills, "Spieler hat ein Skill-System")
	assert_eq(_skills.class_def.skills.size(), 7)
	for skill in _skills.class_def.skills:
		assert_true(_skills.progression.is_learned(skill), "%s gelernt" % skill.id)
	assert_eq(_skills.bar.get_skill(0).id, &"strike", "Linksklick = Hieb")
	assert_eq(_skills.bar.get_skill(1).id, &"cleave", "Rechtsklick = Spaltschlag")
	assert_eq(_skills.fury.current, _skills.fury.maximum, "Wut voll")
	assert_true(_player.basic_attack_handler.is_valid(), "Hieb ersetzt den Standardangriff")


func test_strike_replaces_basic_attack_and_builds_fury() -> void:
	_skills.fury.clear()
	var dummy := _dummy("Front1")
	_player.attack(dummy, false)
	var hit := await _wait_until(func() -> bool: return _hit_count(&"strike") > 0, 3.0)
	assert_true(hit, "Hieb trifft über den Standardangriff")
	assert_lt(dummy.health.current, dummy.health.maximum)
	assert_almost_eq(_skills.fury.current, 10.0, 0.01, "Hieb erzeugt 10 Wut")
	var expected := Stats.get_stat(_player, Enums.Stat.DAMAGE) * 1.0
	assert_almost_eq(_damage_by(&"strike"), expected, 0.01, "100 % Waffenschaden")


func test_cleave_hits_arc_and_costs_fury() -> void:
	await _place_player(Vector3(0, 0, 3))
	assert_true(_skills.try_cast(_skill(&"cleave"), Vector3(0, 0, 0)))
	assert_eq(_player.state, Player.State.CASTING)
	assert_almost_eq(_skills.fury.current, _skills.fury.maximum - 25.0, 0.01, "kostet 25 Wut")
	assert_true(await _wait_cast_done(), "Einsatz endet")
	assert_eq(_player.state, Player.State.IDLE)
	assert_gte(_damaged_dummies().size(), 3, "alle drei Puppen im Halbkreis getroffen")
	var weapon := Stats.get_stat(_player, Enums.Stat.DAMAGE)
	assert_almost_eq(_damage_by(&"cleave") / _hit_count(&"cleave"), weapon * 1.8, 0.01)


func test_whirlwind_channels_while_held_and_drains_fury() -> void:
	await _place_player(Vector3(0, 0, -4))
	var start_fury := _skills.fury.current
	assert_true(_skills.try_cast(_skill(&"whirlwind"), Vector3(0, 0, -4)))
	await wait_seconds(1.0)
	assert_eq(_player.state, Player.State.CASTING, "wirbelt, solange gehalten")
	_skills.release_active()
	await wait_physics_frames(2)
	assert_null(_skills.active_cast)
	assert_eq(_player.state, Player.State.IDLE)
	assert_gte(_damaged_dummies().size(), 3, "Gegner rundherum getroffen")
	assert_gte(_hit_count(&"whirlwind"), 12, "mehrere Takte")
	var spent := start_fury - _skills.fury.current
	assert_between(spent, 18.0, 26.0, "rund 20 Wut pro Sekunde")


func test_whirlwind_moves_towards_point_and_stops_without_fury() -> void:
	var start := _player.global_position
	_skills.fury.clear()
	_skills.fury.gain(10.0)
	assert_true(_skills.try_cast(_skill(&"whirlwind"), Vector3(-12, 0, 6)))
	await wait_seconds(0.9)
	assert_lt(_player.global_position.x, start.x - 1.0, "bewegt sich zum Punkt")
	assert_null(_skills.active_cast, "endet, wenn die Wut leer ist")
	assert_false(_skills.try_cast(_skill(&"whirlwind"), Vector3.ZERO), "ohne Wut kein Start")


func test_war_cry_buffs_damage_and_armor_and_builds_fury() -> void:
	watch_signals(EventBus)
	_skills.fury.clear()
	var damage := Stats.get_stat(_player, Enums.Stat.DAMAGE)
	var armor := Stats.get_stat(_player, Enums.Stat.ARMOR)
	assert_true(_skills.try_cast(_skill(&"war_cry"), Vector3.INF))
	assert_true(_skills.has_buff(ShoutCast.BUFF_KEY))
	assert_almost_eq(Stats.get_stat(_player, Enums.Stat.DAMAGE), damage * 1.2, 0.01, "+20 %")
	assert_almost_eq(Stats.get_stat(_player, Enums.Stat.ARMOR), armor * 1.3, 0.01, "+30 %")
	assert_almost_eq(_skills.fury.current, 20.0, 0.01, "erzeugt 20 Wut")
	assert_almost_eq(_skills.get_cooldown_left(_skill(&"war_cry")), 20.0, 0.1)
	assert_signal_emitted(EventBus, "skill_cooldown_started")
	await _wait_cast_done()
	assert_false(_skills.try_cast(_skill(&"war_cry"), Vector3.INF), "Abklingzeit")
	assert_signal_emitted_with_parameters(
		EventBus, "skill_cast_failed", [_skill(&"war_cry"), &"cooldown"]
	)


func test_leap_jumps_over_enemies_and_damages_on_landing() -> void:
	assert_true(_skills.try_cast(_skill(&"leap"), Vector3(0, 0, -2)))
	await wait_seconds(0.3)
	assert_gt(_player.model_root.position.y, 0.5, "in der Luft")
	assert_true(await _wait_cast_done())
	assert_almost_eq(_player.global_position.z, -2.0, 0.6, "8 m gesprungen, über die Front hinweg")
	assert_eq(_player.model_root.position.y, 0.0)
	assert_eq(_player.collision_mask, Player.BODY_MASK, "Kollision wiederhergestellt")
	assert_gte(_hit_count(&"leap"), 2, "Landung trifft die Gruppe")


func test_leap_is_clamped_to_range() -> void:
	assert_true(_skills.try_cast(_skill(&"leap"), Vector3(0, 0, -40)))
	await _wait_cast_done()
	assert_almost_eq(_player.global_position.z, 6.0 - 8.0, 0.6, "höchstens 8 m")


func test_charge_dashes_through_enemies_and_knocks_them_back() -> void:
	var front := _dummy("Front1")
	var front_start := front.global_position
	assert_true(_skills.try_cast(_skill(&"charge"), Vector3(0, 0, -6)))
	assert_true(await _wait_cast_done())
	assert_lt(_player.global_position.z, 6.0 - 5.0, "mindestens 5 m gestürmt")
	assert_gte(_hit_count(&"charge"), 3, "alle drei Front-Puppen getroffen")
	assert_eq(_hit_count(&"charge"), _damaged_dummies().size(), "jede Puppe nur einmal")
	assert_gt(front.global_position.distance_to(front_start), 0.5, "weggestoßen")


func test_ancients_strike_three_times_at_target() -> void:
	await _place_player(Vector3(4, 0, -2))
	var target := _dummy("Far1").global_position
	assert_true(_skills.try_cast(_skill(&"ancients"), target))
	assert_true(await _wait_cast_done(4.0))
	var far := _dummy("Far1")
	var single := Stats.get_stat(_player, Enums.Stat.DAMAGE) * 2.0
	assert_almost_eq(far.health.maximum - far.health.current, single * 3.0, 0.5, "3 Einschläge")
	assert_almost_eq(_skills.get_cooldown_left(_skill(&"ancients")), 45.0, 2.0)


# --- Eingaben, Abbruch, Fehlschläge --------------------------------------------------------


func test_skill_keys_cast_bar_slots() -> void:
	_player.input_enabled = true
	await tap_action(&"skill_2")
	assert_true(_skills.has_buff(ShoutCast.BUFF_KEY), "Taste 2 = Kriegsschrei")
	await _wait_cast_done()
	_skills.fury.fill()
	await tap_action(&"secondary_action")
	assert_gt(_hit_count(&"cleave") + (1 if _skills.active_cast != null else 0), 0, "Rechtsklick")


func test_dodge_cancels_whirlwind() -> void:
	assert_true(_skills.try_cast(_skill(&"whirlwind"), Vector3(0, 0, 6)))
	await wait_physics_frames(3)
	assert_true(_player.dodge(Vector3.RIGHT))
	assert_null(_skills.active_cast, "Rolle bricht ab")
	assert_eq(_player.state, Player.State.DODGING)
	assert_eq(_player.cast_velocity, Vector3.ZERO)


func test_cast_fails_without_fury_or_rank() -> void:
	watch_signals(EventBus)
	_skills.fury.clear()
	assert_false(_skills.try_cast(_skill(&"cleave"), Vector3.ZERO))
	assert_signal_emitted_with_parameters(
		EventBus, "skill_cast_failed", [_skill(&"cleave"), &"resource"]
	)
	_skills.debug_set_rank(_skill(&"leap"), 0)
	assert_eq(_skills.check_cast(_skill(&"leap")), &"not_learned")


# --- Stufen --------------------------------------------------------------------------------


func test_killing_dummies_levels_up_and_grants_points() -> void:
	watch_signals(EventBus)
	var points := _skills.progression.points
	var life := _player.health.maximum
	for dummy_name: String in ["Front0", "Front1", "Front2"]:
		var hit := HitInfo.create(_player, _dummy(dummy_name), 10000.0)
		Combat.apply_damage(hit)
	assert_eq(_skills.progression.level, 2, "3 × 40 Erfahrung = Stufe 2")
	assert_eq(_skills.progression.experience, 20)
	assert_eq(_skills.progression.points, points + 2, "2 Punkte je Stufe")
	assert_signal_emitted_with_parameters(EventBus, "player_level_up", [2])
	assert_signal_emitted(EventBus, "experience_changed")
	assert_gt(_player.health.maximum, life, "Stufe gibt Leben")
