extends GutTest
## Skillleiste mit 6 Plätzen und Wut (AP5).

var class_def: SkillClassDef


func before_each() -> void:
	class_def = load("res://data/skills/warrior.tres") as SkillClassDef


func _skill(id: StringName) -> SkillDef:
	return class_def.find_skill(id)


func test_bar_has_six_slots_with_actions() -> void:
	var bar := SkillLoadout.new()
	assert_eq(bar.slots.size(), 6)
	assert_eq(SkillLoadout.action_for(0), &"primary_action")
	assert_eq(SkillLoadout.action_for(1), &"secondary_action")
	assert_eq(SkillLoadout.action_for(5), &"skill_4")
	for slot in 6:
		assert_true(InputMap.has_action(SkillLoadout.action_for(slot)), "Aktion in project.godot")


func test_primary_slot_only_takes_basic_skills() -> void:
	var bar := SkillLoadout.new()
	assert_true(bar.assign(0, _skill(&"cleave")).is_empty(), "Kern-Skill nicht auf Linksklick")
	assert_eq(bar.assign(0, _skill(&"strike")), [0] as Array[int])
	assert_eq(bar.first_free_slot(_skill(&"cleave")), 1)


func test_assign_moves_and_swaps() -> void:
	var bar := SkillLoadout.new()
	bar.assign(2, _skill(&"whirlwind"))
	bar.assign(3, _skill(&"leap"))
	var changed := bar.assign(2, _skill(&"leap"))
	assert_eq(changed, [2, 3] as Array[int])
	assert_eq(bar.get_skill(2).id, &"leap")
	assert_eq(bar.get_skill(3).id, &"whirlwind", "getauscht")
	bar.assign(0, _skill(&"strike"))
	bar.assign(1, _skill(&"cleave"))
	bar.assign(0, _skill(&"cleave"))
	assert_eq(bar.get_skill(0).id, &"strike", "Tausch auf Linksklick abgelehnt")
	bar.assign(1, _skill(&"strike"))
	assert_eq(bar.get_skill(1).id, &"strike")
	assert_null(bar.get_skill(0), "Spaltschlag passt nicht auf Linksklick, Platz wird frei")
	assert_eq(bar.to_ids(), ["", "strike", "leap", "whirlwind", "", ""] as Array[String])


func test_fury_spend_gain_and_cap() -> void:
	var fury := ResourcePool.new()
	watch_signals(fury)
	assert_eq(fury.current, 0.0)
	assert_false(fury.spend(10.0))
	assert_eq(fury.gain(30.0), 30.0)
	assert_true(fury.spend(25.0))
	assert_almost_eq(fury.current, 5.0, 0.001)
	assert_eq(fury.gain(500.0), 95.0, "bis zum Maximum")
	fury.set_maximum(50.0)
	assert_eq(fury.current, 50.0)
	assert_signal_emit_count(fury, "changed", 4)
