extends GutTest
## Erfahrung, Stufen, Skillpunkte und Freischaltung (AP5).

var class_def: SkillClassDef
var progression: SkillProgression


func before_each() -> void:
	class_def = load("res://data/skills/warrior.tres") as SkillClassDef
	progression = SkillProgression.new(class_def)


func _skill(id: StringName) -> SkillDef:
	return class_def.find_skill(id)


func test_start_state() -> void:
	assert_eq(progression.level, 1)
	assert_eq(progression.points, 1)
	assert_eq(progression.get_rank(_skill(&"strike")), 1, "Hieb ist gelernt")
	assert_eq(progression.required_experience(), 100)


func test_experience_levels_up_and_grants_points() -> void:
	assert_eq(progression.add_experience(99), 0)
	assert_eq(progression.level, 1)
	assert_eq(progression.add_experience(1), 1)
	assert_eq(progression.level, 2)
	assert_eq(progression.experience, 0)
	assert_eq(progression.points, 3, "1 zu Beginn + 2 je Stufe")


func test_one_big_gain_can_give_several_levels() -> void:
	assert_eq(progression.add_experience(100 + 160 + 50), 2)
	assert_eq(progression.level, 3)
	assert_eq(progression.experience, 50)


func test_level_is_capped_at_ten() -> void:
	progression.add_experience(1_000_000)
	assert_eq(progression.level, 10)
	assert_eq(progression.experience, 0)
	assert_eq(progression.required_experience(), 0)
	assert_eq(progression.points, 1 + 9 * 2)
	assert_eq(progression.add_experience(500), 0, "keine Stufe über 10")


func test_categories_unlock_by_spent_points() -> void:
	var cleave := _skill(&"cleave")
	assert_false(progression.is_unlocked(cleave), "Kern ab 2 verteilten Punkten")
	assert_eq(progression.lock_reason(cleave), "Ab 2 verteilten Punkten")
	assert_false(progression.rank_up(cleave))
	assert_true(progression.rank_up(_skill(&"strike")), "Hieb Rang 2")
	assert_true(progression.is_unlocked(cleave))
	assert_eq(progression.points, 0)
	assert_false(progression.rank_up(cleave), "keine Punkte mehr")
	assert_false(progression.is_unlocked(_skill(&"ancients")), "Ultimativ ab 9 Punkten")


func test_rank_is_capped_and_upgrade_starts_at_rank_two() -> void:
	progression.set_level(10)
	var strike := _skill(&"strike")
	assert_false(progression.is_upgraded(strike))
	for i in 10:
		progression.rank_up(strike)
	assert_eq(progression.get_rank(strike), 5, "höchstens Rang 5")
	assert_true(progression.is_upgraded(strike))


func test_tree_state_for_ui() -> void:
	var state := progression.build_state()
	assert_eq(state.skills.size(), 7)
	assert_eq(state.points, 1)
	assert_eq(state.get_rank(_skill(&"strike")), 1)
	assert_true(state.is_unlocked(_skill(&"strike")))
	assert_false(state.is_unlocked(_skill(&"leap")))
	assert_eq(state.lock_reasons[&"leap"], "Ab 6 verteilten Punkten")
	assert_true(state.can_rank_up(_skill(&"strike")))


func test_save_and_load() -> void:
	progression.add_experience(150)
	progression.rank_up(_skill(&"strike"))
	var data := progression.to_dict()
	var other := SkillProgression.new(class_def)
	other.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(other.level, 2)
	assert_eq(other.experience, 50)
	assert_eq(other.points, progression.points)
	assert_eq(other.get_rank(_skill(&"strike")), 2)
