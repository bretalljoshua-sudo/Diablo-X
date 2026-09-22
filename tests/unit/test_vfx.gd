extends GutTest
## AP1: Effekte kommen aus Pools und räumen sich auf, Schadenszahlen erscheinen bei damage_dealt,
## Tod löst auf, Beute bekommt Lichtsäulen, Skills lösen ihren Effekt aus.


class Target:
	extends Node3D

	func _init() -> void:
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.position = Vector3(0, 1, 0)
		add_child(mesh)


func after_each() -> void:
	Vfx.clear()


func test_spawn_returns_effect_that_returns_to_pool() -> void:
	var effect := Vfx.spawn(&"hit", Vector3(1, 0, 2)) as VfxEffect
	assert_not_null(effect)
	assert_true(effect.is_active())
	assert_eq(effect.global_position, Vector3(1, 0, 2))
	assert_gt(Vfx.active_count(&"hit"), 0)
	await wait_seconds(effect.lifetime + 0.2)
	assert_false(effect.is_active(), "nach der Lebensdauer frei")
	assert_false(effect.visible)
	assert_gt(Vfx.pooled_count(&"hit"), 0, "zurück im Pool")
	var again := Vfx.spawn(&"hit", Vector3.ZERO)
	assert_eq(again, effect, "wird wiederverwendet statt neu gebaut")


func test_unknown_key_returns_null() -> void:
	assert_null(Vfx.spawn(&"gibt_es_nicht", Vector3.ZERO))
	assert_engine_error_count(0)


func test_pool_is_capped_per_key() -> void:
	for i in Vfx.MAX_PER_KEY + 10:
		Vfx.spawn(&"dust", Vector3.ZERO)
	assert_eq(Vfx.active_count(&"dust"), Vfx.MAX_PER_KEY)


func test_every_library_effect_builds() -> void:
	for key: StringName in VfxLibrary.SPECS:
		var effect := VfxLibrary.build(key)
		autofree(effect)
		assert_gt(effect.emitters.size(), 0, String(key))
		assert_gt(effect.lifetime, 0.0, String(key))


func test_damage_dealt_shows_number() -> void:
	var target: Target = add_child_autofree(Target.new())
	target.global_position = Vector3(2, 0, 0)
	var hit := HitInfo.create(null, target, 30.0)
	var result := DamageResult.new()
	result.amount = 27.6
	EventBus.damage_dealt.emit(hit, result)
	var numbers := Vfx.active_numbers()
	assert_eq(numbers.size(), 1)
	assert_eq(numbers[0].text, "28")
	assert_true(numbers[0].modulate.is_equal_approx(DamageNumber.COLOR_NORMAL))
	assert_gt(numbers[0].global_position.y, 1.0, "über der Figur")
	assert_gt(Vfx.active_count(&"blood"), 0, "Blut bei körperlichem Schaden")


func test_crit_and_player_numbers() -> void:
	var target: Target = add_child_autofree(Target.new())
	var crit_hit := HitInfo.create(null, target, 30.0)
	var crit := DamageResult.new()
	crit.amount = 50.0
	crit.crit = true
	EventBus.damage_dealt.emit(crit_hit, crit)
	var number := Vfx.active_numbers()[0]
	assert_eq(number.text, "50!")
	assert_true(number.modulate.is_equal_approx(DamageNumber.COLOR_CRIT))
	assert_gt(Vfx.active_count(&"crit"), 0)
	assert_eq(
		DamageNumber.color_for(false, true, Enums.DamageType.PHYSICAL), DamageNumber.COLOR_PLAYER
	)
	assert_eq(
		DamageNumber.color_for(false, false, Enums.DamageType.FIRE),
		DamageNumber.TYPE_COLORS[Enums.DamageType.FIRE]
	)


func test_numbers_disappear() -> void:
	var number := Vfx.show_damage_number(Vector3.ZERO, 5.0)
	assert_true(number.is_active())
	await wait_seconds(DamageNumber.LIFETIME + 0.2)
	assert_false(number.is_active())
	assert_eq(Vfx.active_numbers().size(), 0)


func test_no_number_for_zero_damage() -> void:
	var target: Target = add_child_autofree(Target.new())
	EventBus.damage_dealt.emit(HitInfo.create(null, target, 0.0), DamageResult.new())
	assert_eq(Vfx.active_numbers().size(), 0)


func test_hit_effect_by_damage_type_and_target() -> void:
	var target: Target = add_child_autofree(Target.new())
	assert_eq(Vfx.hit_key_for(target, Enums.DamageType.PHYSICAL), &"blood")
	assert_eq(Vfx.hit_key_for(target, Enums.DamageType.FIRE), &"fire_hit")
	assert_eq(Vfx.hit_key_for(target, Enums.DamageType.COLD), &"cold_hit")
	target.name = "SkeletonSwarm"
	assert_eq(Vfx.hit_key_for(target, Enums.DamageType.PHYSICAL), &"bone_chips")
	target.set_meta(&"hit_vfx", &"sparks")
	assert_eq(Vfx.hit_key_for(target, Enums.DamageType.PHYSICAL), &"sparks")


func test_death_dissolves_and_spawn_restores() -> void:
	var target: Target = add_child_autofree(Target.new())
	var mesh := target.get_child(0) as MeshInstance3D
	EventBus.entity_died.emit(target, null)
	assert_true(mesh.material_override is ShaderMaterial, "Auflöse-Shader")
	assert_eq((mesh.material_override as ShaderMaterial).shader, MaterialLibrary.DISSOLVE_SHADER)
	assert_gt(Vfx.active_count(&"death_burst"), 0)
	await wait_seconds(Vfx.DISSOLVE_DELAY + Vfx.DISSOLVE_TIME + 0.2)
	var progress: float = (mesh.material_override as ShaderMaterial).get_shader_parameter(
		&"progress"
	)
	assert_almost_eq(progress, 1.0, 0.01, "ganz aufgelöst")
	EventBus.entity_spawned.emit(target)
	assert_null(mesh.material_override, "Wiederverwendung setzt zurück")


func test_hidden_model_dissolves_as_copy() -> void:
	var target: Target = add_child_autofree(Target.new())
	var mesh := target.get_child(0) as MeshInstance3D
	target.visible = false
	var ghosts := Vfx.dissolve(target)
	assert_eq(ghosts.size(), 1)
	assert_ne(ghosts[0], mesh)
	assert_true(ghosts[0].has_meta(&"ap1_ghost"))
	assert_null(mesh.material_override, "das Original bleibt unberührt")
	await wait_seconds(Vfx.DISSOLVE_TIME + 0.3)
	assert_false(is_instance_valid(ghosts[0]), "Kopie räumt sich auf")


func test_player_does_not_dissolve() -> void:
	var target: Target = add_child_autofree(Target.new())
	var previous := Game.player
	Game.player = target
	EventBus.entity_died.emit(target, null)
	Game.player = previous
	assert_null((target.get_child(0) as MeshInstance3D).material_override)


func test_loot_beam_by_rarity() -> void:
	var legendary := ItemInstance.new()
	legendary.rarity = Enums.Rarity.LEGENDARY
	var normal := ItemInstance.new()
	normal.rarity = Enums.Rarity.NORMAL
	EventBus.loot_dropped.emit(legendary, Vector3(3, 0, 3))
	EventBus.loot_dropped.emit(normal, Vector3(4, 0, 3))
	assert_eq(Vfx.loot_beam_count(), 1, "nur seltene Beute leuchtet")
	EventBus.loot_picked_up.emit(legendary)
	assert_eq(Vfx.loot_beam_count(), 0, "Aufheben löscht die Säule")


func test_level_unloading_clears_everything() -> void:
	var item := ItemInstance.new()
	item.rarity = Enums.Rarity.UNIQUE
	Vfx.add_loot_beam(item, Vector3.ZERO)
	Vfx.spawn(&"slam", Vector3.ZERO)
	Vfx.show_damage_number(Vector3.ZERO, 3.0)
	EventBus.level_unloading.emit(LevelLayout.new())
	assert_eq(Vfx.loot_beam_count(), 0)
	assert_eq(Vfx.active_count(), 0)
	assert_eq(Vfx.active_numbers().size(), 0)


func test_skill_cast_spawns_its_effect() -> void:
	var caster: Target = add_child_autofree(Target.new())
	caster.global_position = Vector3(5, 0, 5)
	var skill := SkillDef.new()
	skill.vfx_key = &"cleave"
	EventBus.skill_cast.emit(caster, skill, Vector3(9, 0, 9))
	assert_eq(Vfx.active_count(&"skill_cleave"), 1, "kurzer Schlüssel aus AP5")
	var guessed := SkillDef.new()
	guessed.behavior = &"whirlwind"
	assert_eq(Vfx.skill_key_for(guessed), &"skill_whirlwind", "ohne vfx_key über das Verhalten")
	assert_eq(Vfx.skill_key_for(SkillDef.new()), &"")


func test_skill_cast_leaves_cast_driven_effects_to_ap5() -> void:
	var caster: Target = add_child_autofree(Target.new())
	var skill := SkillDef.new()
	skill.vfx_key = &"leap"
	EventBus.skill_cast.emit(caster, skill, Vector3(4, 0, 0))
	assert_eq(Vfx.active_count(&"skill_leap"), 0, "die Landung startet AP5 über Vfx.spawn")
	assert_not_null(Vfx.spawn(&"leap", Vector3(4, 0, 0)))
	assert_eq(Vfx.active_count(&"skill_leap"), 1)


func test_spawn_resolves_short_keys_and_aliases() -> void:
	assert_eq(Vfx.resolve_key(&"war_cry"), &"skill_war_cry")
	assert_eq(Vfx.resolve_key(&"blood"), &"blood")
	assert_eq(Vfx.resolve_key(&"ancients"), &"skill_ancients_strike", "ein Einschlag pro Schlag")
	assert_eq(Vfx.resolve_key(&"gibt_es_nicht"), &"")
	assert_null(Vfx.spawn(&"gibt_es_nicht", Vector3.ZERO), "SkillFx zeigt dann den Kreis")


func test_same_skill_effect_is_not_doubled() -> void:
	var caster: Target = add_child_autofree(Target.new())
	var skill := SkillDef.new()
	skill.vfx_key = &"strike"
	EventBus.skill_cast.emit(caster, skill, Vector3(1, 0, 0))
	var from_skill := Vfx.spawn(&"strike", Vector3(0.5, 0, 0))
	assert_not_null(from_skill, "liefert den laufenden Effekt, damit AP5 keinen Kreis zeigt")
	assert_eq(Vfx.active_count(&"skill_strike"), 1)
	Vfx.spawn(&"strike", Vector3(8, 0, 0))
	assert_eq(Vfx.active_count(&"skill_strike"), 2, "weit weg ist ein neuer Treffer")


func test_blood_decals_respect_budget() -> void:
	var budget := Graphics.get_preset().max_decals
	for i in budget + 5:
		Vfx.add_blood_decal(Vector3(i, 3, 0))
	assert_eq(Vfx.decal_count(), budget)
