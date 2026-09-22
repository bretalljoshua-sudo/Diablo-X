extends SkillsSimTest
## Simulationstests für AP5: Aspekte und einzigartige Kräfte (AP4) verändern Skills,
## Verbesserungen ab Rang 2, Schnittstelle zur UI und Speichern.

# --- Aspekte -------------------------------------------------------------------------------


func test_aspect_maelstrom_pulls_enemies_into_whirlwind() -> void:
	var dummy := _dummy("Pack1")
	await _place_player(Vector3(0.2, 0, -9))
	var before := dummy.global_position.distance_to(_player.global_position)
	assert_true(_skills.try_cast(_skill(&"whirlwind"), _player.global_position))
	await wait_seconds(0.8)
	_skills.release_active()
	var without := dummy.global_position.distance_to(_player.global_position)
	assert_almost_eq(without, before, 0.1, "ohne Aspekt bleibt die Puppe stehen")
	_scene.set_aspect_set(1)
	_skills.fury.fill()
	await wait_physics_frames(2)
	assert_true(_skills.try_cast(_skill(&"whirlwind"), _player.global_position))
	await wait_seconds(0.8)
	_skills.release_active()
	var after := dummy.global_position.distance_to(_player.global_position)
	assert_lt(after, before - 0.8, "Aspekt des Mahlstroms zieht heran")


func test_aspect_tremor_makes_leap_stun() -> void:
	_scene.set_aspect_set(1)
	assert_true(_skills.try_cast(_skill(&"leap"), Vector3(0, 0, -2)))
	await _wait_cast_done()
	assert_true(Components.is_stunned(_dummy("Pack3")), "Aspekt der Erschütterung betäubt")


func test_aspect_stampede_and_cruelty() -> void:
	assert_true(_skills.try_cast(_skill(&"charge"), Vector3(0, 0, -6)))
	await _wait_cast_done()
	var base_damage := _damage_by(&"charge") / _hit_count(&"charge")
	_scene.reset()
	_hits.clear()
	_results.clear()
	await _place_player(Vector3(0, 0, 6))
	_scene.set_aspect_set(3)
	assert_true(_skills.try_cast(_skill(&"charge"), Vector3(0, 0, -6)))
	await _wait_cast_done()
	var boosted := _damage_by(&"charge") / _hit_count(&"charge")
	assert_almost_eq(boosted, base_damage * 1.5, 0.01, "Aspekt des Sturmlaufs: +50 %")
	_skills.fury.clear()
	_player.attack(_dummy("Pack3"), false)
	await _wait_until(func() -> bool: return _hit_count(&"strike") > 0, 3.0)
	assert_almost_eq(_skills.fury.current, 13.0, 0.01, "Aspekt der Grausamkeit: +30 % Wut")


func test_aspects_bloodlust_and_flame_cry() -> void:
	_scene.set_aspect_set(2)
	_player.health.take_damage(100.0)
	var life := _player.health.current
	await _place_player(Vector3(0, 0, 3))
	assert_true(_skills.try_cast(_skill(&"cleave"), Vector3(0, 0, 0)))
	await _wait_cast_done()
	var healed := _player.health.current - life
	assert_almost_eq(healed, _damage_by(&"cleave") * 0.05, 0.05, "Blutdurst heilt 5 %")
	assert_true(_skills.try_cast(_skill(&"war_cry"), Vector3.INF))
	await wait_seconds(1.2)
	assert_gt(_damage_by(&"war_cry", Enums.DamageType.FIRE), 0.0, "Flammenschrei: Feuerring")


func test_unique_powers_crown_and_wrath() -> void:
	_scene.set_aspect_set(4)
	await _place_player(Vector3(0, 0, -4))
	assert_true(_skills.try_cast(_skill(&"whirlwind"), Vector3(0, 0, -4)))
	await wait_seconds(0.3)
	_skills.release_active()
	assert_true(_dummy("Pack3").status_effects.has_effect(&"skill_burn"), "Krone der Asche")
	await _place_player(Vector3(4, 0, -2))
	var far := _dummy("Far1")
	# Mit der Axt sterben die Puppen sonst vor dem vierten Einschlag.
	for dummy_name: String in ["Far0", "Far1", "Far2"]:
		var dummy := _dummy(dummy_name)
		dummy.stats.base_stats.set_value(Enums.Stat.MAX_LIFE, 5000.0)
		dummy.stats.base_stats = dummy.stats.base_stats
		dummy.health.reset_to_full()
	assert_true(_skills.try_cast(_skill(&"ancients"), far.global_position))
	await _wait_cast_done(4.0)
	var on_far := 0
	for hit in _hits:
		if hit.skill != null and hit.skill.id == &"ancients" and hit.target == far:
			on_far += 1
	assert_eq(on_far, 4, "Ahnenzorn: ein Einschlag mehr")


# --- Verbesserungen ------------------------------------------------------------------------


func test_upgrades_at_rank_two() -> void:
	for skill in _skills.class_def.skills:
		_skills.debug_set_rank(skill, 2)
		assert_true(_skills.progression.is_upgraded(skill), "%s verbessert" % skill.id)
	# Spaltschlag verlangsamt.
	await _place_player(Vector3(0, 0, 3))
	assert_true(_skills.try_cast(_skill(&"cleave"), Vector3(0, 0, 0)))
	await _wait_cast_done()
	assert_true(_dummy("Front1").status_effects.has_effect(&"skill_slow"), "Spaltschlag")
	# Kriegsschrei heilt.
	_player.health.take_damage(60.0)
	var life := _player.health.current
	assert_true(_skills.try_cast(_skill(&"war_cry"), Vector3.INF))
	assert_almost_eq(_player.health.current - life, _player.health.maximum * 0.2, 0.5)
	await _wait_cast_done()
	# Sprung: Abklingzeit sinkt bei Treffer.
	await _place_player(Vector3(0, 0, 6))
	assert_true(_skills.try_cast(_skill(&"leap"), Vector3(0, 0, -2)))
	await _wait_cast_done()
	assert_lt(_skills.get_cooldown_left(_skill(&"leap")), 12.0 - 4.0 + 0.01, "−4 s")
	# Zorn der Ahnen: mehr Rüstung.
	assert_true(_skills.try_cast(_skill(&"ancients"), Vector3(0, 0, -6)))
	assert_true(_skills.has_buff(AncientsCast.BUFF_KEY))


func test_strike_upgrade_every_third_hit_is_a_full_circle() -> void:
	_skills.debug_set_rank(_skill(&"strike"), 2)
	await _place_player(Vector3(0, 0, -4))
	var counts: Array[int] = []
	for i in 3:
		var before := _hit_count(&"strike")
		_player.attack_direction(Vector3.FORWARD)
		await _wait_until(func() -> bool: return _player.state == Player.State.IDLE, 2.0)
		counts.append(_hit_count(&"strike") - before)
	assert_lt(counts[0], 4, "normaler Hieb trifft nur vorn")
	assert_eq(counts[2], 4, "dritter Hieb trifft alle vier Puppen rundherum")


func test_whirlwind_and_charge_upgrades_return_fury() -> void:
	_skills.debug_set_rank(_skill(&"charge"), 2)
	_skills.debug_set_rank(_skill(&"whirlwind"), 2)
	_skills.fury.clear()
	assert_true(_skills.try_cast(_skill(&"charge"), Vector3(0, 0, -6)))
	await _wait_cast_done()
	assert_almost_eq(_skills.fury.current, 8.0 * _hit_count(&"charge"), 0.01, "8 Wut je Gegner")
	await _place_player(Vector3(0, 0, -4))
	_skills.fury.clear()
	_skills.fury.gain(50.0)
	assert_true(_skills.try_cast(_skill(&"whirlwind"), Vector3(0, 0, -4)))
	await wait_seconds(1.0)
	_skills.release_active()
	assert_gt(_skills.fury.current, 50.0 - 20.0 + 8.0, "Wirbelsturm gibt Wut je Treffer zurück")


# --- Schnittstelle zur UI (AP7) ------------------------------------------------------------


func test_ui_requests_rank_up_and_slot_assign() -> void:
	watch_signals(EventBus)
	_skills.set_level(3)
	var cleave := _skill(&"cleave")
	var rank := _skills.progression.get_rank(cleave)
	EventBus.skill_rank_up_requested.emit(cleave)
	assert_eq(_skills.progression.get_rank(cleave), rank + 1)
	assert_signal_emitted(EventBus, "skill_tree_changed")
	EventBus.skill_slot_assign_requested.emit(5, _skill(&"charge"))
	assert_eq(_skills.bar.get_skill(5).id, &"charge")
	assert_signal_emitted_with_parameters(EventBus, "skill_slot_changed", [5, _skill(&"charge")])
	_skills.broadcast_state()
	assert_signal_emitted(EventBus, "resource_changed")
	assert_signal_emitted(EventBus, "experience_changed")


func test_save_and_load_skill_state() -> void:
	_skills.set_level(4)
	_skills.debug_set_rank(_skill(&"leap"), 3)
	_skills.assign_slot(2, _skill(&"charge"))
	var data: Dictionary = JSON.parse_string(JSON.stringify(_skills.to_dict()))
	_skills.set_level(1)
	_skills.progression.setup(_skills.class_def)
	_skills.from_dict(data)
	assert_eq(_skills.progression.level, 4)
	assert_eq(_skills.progression.get_rank(_skill(&"leap")), 3)
	assert_eq(_skills.bar.get_skill(2).id, &"charge")
	assert_eq(_skills.bar.get_skill(0).id, &"strike")
