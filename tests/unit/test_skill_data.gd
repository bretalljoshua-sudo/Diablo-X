extends GutTest
## Daten der Krieger-Skills (data/skills/) und Aspekt-Anbindung über Tags (AP5).

const BEHAVIORS: Array[StringName] = [
	&"melee", &"whirlwind", &"shout", &"leap", &"charge", &"ancients"
]

var class_def: SkillClassDef


func before_each() -> void:
	class_def = load("res://data/skills/warrior.tres") as SkillClassDef


func test_warrior_has_seven_skills_in_plan_categories() -> void:
	var expected := {
		&"strike": Enums.SkillCategory.BASIC,
		&"cleave": Enums.SkillCategory.CORE,
		&"whirlwind": Enums.SkillCategory.CORE,
		&"war_cry": Enums.SkillCategory.DEFENSIVE,
		&"leap": Enums.SkillCategory.MOBILITY,
		&"charge": Enums.SkillCategory.MOBILITY,
		&"ancients": Enums.SkillCategory.ULTIMATE,
	}
	assert_eq(class_def.skills.size(), 7)
	for id: StringName in expected:
		var skill := class_def.find_skill(id)
		assert_not_null(skill, "%s vorhanden" % id)
		if skill != null:
			assert_eq(skill.category, expected[id], "%s Kategorie" % id)
	assert_eq(class_def.find_skill(&"whirlwind").targeting, Enums.Targeting.CHANNEL)


func test_every_skill_has_text_behavior_upgrade_and_catalog_tags() -> void:
	var catalog := load("res://data/aspects/skill_tags.tres") as SkillTagCatalog
	for skill in class_def.skills:
		assert_ne(skill.display_name, "", "%s Name" % skill.id)
		assert_ne(skill.description, "", "%s Beschreibung" % skill.id)
		assert_ne(skill.upgrade_description, "", "%s Verbesserung" % skill.id)
		assert_true(skill.behavior in BEHAVIORS, "%s Verhalten" % skill.id)
		assert_true(skill.id in skill.tags, "%s trägt die eigene id als Tag" % skill.id)
		for tag in skill.tags:
			assert_true(catalog.tags.has(tag), "%s: Tag %s im Katalog" % [skill.id, tag])


func test_basic_builds_and_core_spends_fury() -> void:
	for skill in class_def.skills:
		if skill.category == Enums.SkillCategory.BASIC:
			assert_gt(skill.generate, 0.0, "%s baut Wut auf" % skill.id)
		if skill.category == Enums.SkillCategory.CORE:
			assert_gt(skill.cost, 0.0, "%s verbraucht Wut" % skill.id)


func test_every_legendary_aspect_changes_some_warrior_skill() -> void:
	var db := ItemDatabase.get_default()
	var powers: Array[AspectDef] = db.aspects.duplicate()
	for unique in db.uniques:
		powers.append(unique.power)
	for aspect in powers:
		var affected := 0
		for skill in class_def.skills:
			var mods := SkillModifiers.build(skill, 1, [aspect], 0.1)
			if not mods.aspects.is_empty():
				affected += 1
		assert_gt(affected, 0, "%s wirkt auf mindestens einen Skill" % aspect.id)


func test_modifiers_from_rank_and_aspects() -> void:
	var db := ItemDatabase.get_default()
	var charge := class_def.find_skill(&"charge")
	var stampede := db.get_aspect(&"aspect_stampede")
	var cruelty := db.get_aspect(&"aspect_cruelty")
	var plain := SkillModifiers.build(charge, 1, [], 0.1)
	assert_eq(plain.damage_factor, 1.0)
	assert_false(plain.upgraded)
	var ranked := SkillModifiers.build(charge, 3, [stampede, cruelty], 0.1)
	assert_almost_eq(ranked.damage_factor, 1.2 * 1.5, 0.0001, "Rang 3 (+20 %) × Sturmlauf (+50 %)")
	assert_eq(ranked.knockback, 3.0)
	assert_true(ranked.upgraded)
	assert_eq(ranked.aspects.size(), 1, "Grausamkeit wirkt nur auf Basis-Skills")
	var strike := class_def.find_skill(&"strike")
	assert_almost_eq(SkillModifiers.build(strike, 1, [cruelty], 0.1).resource_factor, 1.3, 0.0001)
	var whirlwind := class_def.find_skill(&"whirlwind")
	var maelstrom := SkillModifiers.build(whirlwind, 1, [db.get_aspect(&"aspect_maelstrom")], 0.1)
	assert_eq(maelstrom.pull_radius, 5.0)
	assert_eq(maelstrom.pull_strength, 2.0)
	var leap := class_def.find_skill(&"leap")
	assert_eq(
		SkillModifiers.build(leap, 1, [db.get_aspect(&"aspect_tremor")], 0.1).stun_duration, 1.5
	)
