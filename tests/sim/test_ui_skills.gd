extends UiSimTest
## „Fertig, wenn“ von AP7, Teil 2: Skillpunkte verteilen mit Maus und Tastatur, gegen die
## Beispieldaten der Testszene (debug/ui_test_skills.gd spielt AP5).

var skills: Node
var tree: SkillTreeWindow


func before_each() -> void:
	await super()
	skills = scene.get(&"skills")
	tree = ui.skill_tree_window
	await tap_action(&"open_skills")
	assert_true(tree.is_open())


func test_distribute_points_with_mouse() -> void:
	assert_eq(tree.state.points, 2, "Beispieldaten starten mit 2 Punkten")
	var strike: SkillDef = skills.find(&"strike")
	var cleave: SkillDef = skills.find(&"cleave")
	var ancients: SkillDef = skills.find(&"ancients")
	assert_false(tree.state.is_unlocked(cleave), "Kern ist anfangs gesperrt")
	await click_control(tree.get_node_for(&"ancients"))
	assert_eq(tree.state.get_rank(ancients), 0, "gesperrter Skill bleibt bei 0")
	await click_control(tree.get_node_for(&"strike"))
	assert_eq(tree.state.get_rank(strike), 1, "Klick erhöht den Rang")
	assert_eq(tree.state.points, 1)
	assert_true(tree.state.is_unlocked(cleave), "ein verteilter Punkt schaltet Kern frei")
	await click_control(tree.get_node_for(&"cleave"))
	assert_eq(tree.state.get_rank(cleave), 1)
	assert_eq(tree.state.points, 0)
	await click_control(tree.get_node_for(&"strike"))
	assert_eq(tree.state.get_rank(strike), 1, "ohne Punkte keine Änderung")
	assert_eq(ui.hud.skill_bar.slots[0].skill, strike, "neuer Skill liegt auf der Leiste")
	# Auf die Leiste legen per Knopf.
	await click_control(tree.get_node_for(&"cleave"))
	await click_control(tree.find_child("Assign5", true, false) as Button)
	assert_eq(ui.hud.skill_bar.slots[5].skill, cleave, "Knopf 4 legt Spaltschlag auf Taste 4")


func test_distribute_points_with_keyboard() -> void:
	skills.gain_experience(skills.required_experience())
	await wait_process_frames(1)
	assert_eq(tree.state.points, 3, "Stufenaufstieg gibt einen Punkt")
	var strike: SkillDef = skills.find(&"strike")
	var node := tree.get_node_for(&"strike")
	assert_true(node.has_focus(), "erster Skill hat beim Öffnen den Fokus")
	await press_key(KEY_ENTER)
	await press_key(KEY_ENTER)
	assert_eq(tree.state.get_rank(strike), 2, "Enter erhöht den Rang")
	# Pfeil nach unten wechselt in die Kern-Reihe.
	await press_key(KEY_DOWN)
	var focused := get_viewport().gui_get_focus_owner() as SkillNode
	assert_not_null(focused, "Fokus liegt auf einem Skill")
	var core_skill := focused.skill
	assert_eq(core_skill.category, Enums.SkillCategory.CORE)
	await press_key(KEY_ENTER)
	assert_eq(tree.state.get_rank(core_skill), 1)
	assert_eq(tree.state.points, 0)
	assert_eq(get_viewport().gui_get_focus_owner(), focused, "Fokus bleibt auf dem Skill")
	# Taste 2 legt den gewählten Skill auf Platz „2“.
	await press_key(KEY_2)
	assert_eq(ui.hud.skill_bar.slots[SkillBar.FIRST_KEY_SLOT + 1].skill, core_skill)


func test_skill_bar_shows_cooldown_and_resource() -> void:
	var war_cry: SkillDef = skills.find(&"war_cry")
	skills.ranks[war_cry.id] = 1
	skills.assign(2, war_cry)
	await wait_process_frames(1)
	var slot := ui.hud.skill_bar.slots[2]
	assert_eq(slot.skill, war_cry)
	assert_true(skills.cast(2, Game.player))
	await wait_process_frames(2)
	assert_true(slot.is_on_cooldown(), "Abklingzeit läuft")
	assert_almost_eq(slot.cooldown_total, war_cry.cooldown, 0.01)
	assert_gt(ui.hud.fury_orb.value, 0.0, "Kriegsschrei erzeugt Wut")
	var cleave: SkillDef = skills.find(&"cleave")
	skills.ranks[cleave.id] = 1
	skills.assign(3, cleave)
	skills.fury = 0.0
	EventBus.resource_changed.emit(0.0, 100.0)
	await wait_process_frames(1)
	assert_false(ui.hud.skill_bar.slots[3].affordable, "zu wenig Wut für Spaltschlag")
