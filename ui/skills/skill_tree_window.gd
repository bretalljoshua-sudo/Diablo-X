class_name SkillTreeWindow
extends UiWindow
## Skillbaum (Taste K). Zeigt den SkillTreeState, den AP5 über EventBus.skill_tree_changed sendet,
## gruppiert nach Kategorie. Wünsche gehen als Signale zurück an AP5:
## skill_rank_up_requested(skill) und skill_slot_assign_requested(slot, skill).
##
## Maus: Klick erhöht den Rang, Rechtsklick legt den Skill auf die rechte Maustaste,
## Knöpfe unten legen ihn auf einen Platz der Leiste.
## Tastatur: Pfeiltasten wählen, Enter erhöht den Rang, 1 bis 4 legen ihn auf die Leiste.

const CATEGORY_NAMES: Dictionary[Enums.SkillCategory, String] = {
	Enums.SkillCategory.BASIC: "Basis",
	Enums.SkillCategory.CORE: "Kern",
	Enums.SkillCategory.DEFENSIVE: "Verteidigung",
	Enums.SkillCategory.MOBILITY: "Mobilität",
	Enums.SkillCategory.ULTIMATE: "Ultimativ",
}

var state: SkillTreeState = SkillTreeState.new()
## Skills auf der Leiste, Index wie EventBus.skill_slot_changed.
var bar_skills: Array[SkillDef] = []
var nodes: Dictionary[StringName, SkillNode] = {}
var selected_skill: SkillDef

var _points_label: Label
var _rows: VBoxContainer
var _details: RichTextLabel
var _rank_button: Button
var _assign_buttons: Array[Button] = []
var _lock_labels: Dictionary[Enums.SkillCategory, Label] = {}


func _init() -> void:
	super(&"skills", "Skillbaum")
	bar_skills.resize(SkillBar.SLOT_COUNT)
	_points_label = Label.new()
	_points_label.name = "PointsLabel"
	_points_label.theme_type_variation = &"GoldLabel"
	body.add_child(_points_label)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 4)
	body.add_child(_rows)
	body.add_child(HSeparator.new())
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = true
	_details.scroll_active = false
	_details.custom_minimum_size = Vector2(520, 110)
	body.add_child(_details)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 6)
	body.add_child(actions)
	_rank_button = Button.new()
	_rank_button.name = "RankUpButton"
	_rank_button.text = "Rang erhöhen"
	_rank_button.focus_mode = Control.FOCUS_NONE
	_rank_button.pressed.connect(func() -> void: request_rank_up(selected_skill))
	actions.add_child(_rank_button)
	var caption := Label.new()
	caption.theme_type_variation = &"MutedLabel"
	caption.text = "  Auf Leiste:"
	actions.add_child(caption)
	for slot in SkillBar.SLOT_COUNT:
		var assign := Button.new()
		assign.name = "Assign%d" % slot
		assign.text = SkillBar.SLOT_LABELS[slot]
		assign.focus_mode = Control.FOCUS_NONE
		assign.tooltip_text = SkillBar.SLOT_NAMES[slot]
		assign.pressed.connect(func() -> void: request_slot_assign(slot, selected_skill))
		actions.add_child(assign)
		_assign_buttons.append(assign)
	var hint := Label.new()
	hint.theme_type_variation = &"MutedLabel"
	hint.text = "Klick oder Enter: Rang erhöhen · 1–4 oder Rechtsklick: auf die Leiste legen"
	body.add_child(hint)
	EventBus.skill_tree_changed.connect(set_state)
	EventBus.skill_slot_changed.connect(_on_skill_slot_changed)
	_rebuild()


func set_state(p_state: SkillTreeState) -> void:
	state = p_state if p_state != null else SkillTreeState.new()
	_rebuild()


## Bittet AP5 um einen Rang mehr. false, wenn es laut Stand nicht geht
## (keine Punkte, gesperrt, höchster Rang).
func request_rank_up(skill: SkillDef) -> bool:
	if skill == null or not state.can_rank_up(skill):
		return false
	EventBus.skill_rank_up_requested.emit(skill)
	return true


func request_slot_assign(slot: int, skill: SkillDef) -> bool:
	if skill == null or state.get_rank(skill) <= 0:
		return false
	EventBus.skill_slot_assign_requested.emit(slot, skill)
	return true


func get_node_for(skill_id: StringName) -> SkillNode:
	return nodes.get(skill_id, null)


func _on_opened() -> void:
	var focus_id := selected_skill.id if selected_skill != null else &""
	var target: SkillNode = nodes.get(focus_id, null)
	if target == null and not nodes.is_empty():
		target = nodes.values()[0]
	if target != null:
		target.grab_focus()


func _on_skill_slot_changed(slot: int, skill: SkillDef) -> void:
	if slot < 0 or slot >= bar_skills.size():
		return
	bar_skills[slot] = skill
	_apply_states()


func _rebuild() -> void:
	_points_label.text = "Freie Skillpunkte: %d" % state.points
	var ids: Array[StringName] = []
	for skill in state.skills:
		ids.append(skill.id)
	if ids != nodes.keys():
		_rebuild_rows()
	for skill in state.skills:
		nodes[skill.id].skill = skill
	for category: Enums.SkillCategory in _lock_labels:
		var reason := ""
		for skill in state.skills:
			if skill.category == category and not state.is_unlocked(skill):
				reason = state.lock_reasons.get(skill.id, "Gesperrt")
				break
		_lock_labels[category].text = "Gesperrt: " + reason if not reason.is_empty() else ""
	if selected_skill != null:
		selected_skill = state.find_skill(selected_skill.id)
	_apply_states()


## Baut die Reihen neu auf (nur wenn sich die Liste der Skills ändert, damit der Fokus bleibt).
func _rebuild_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	nodes.clear()
	_lock_labels.clear()
	for category: Enums.SkillCategory in CATEGORY_NAMES:
		var skills := state.skills.filter(func(s: SkillDef) -> bool: return s.category == category)
		if skills.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)
		_rows.add_child(row)
		var caption := Label.new()
		caption.text = CATEGORY_NAMES[category]
		caption.custom_minimum_size.x = 120
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(caption)
		for skill: SkillDef in skills:
			var node := SkillNode.new(skill)
			node.pressed.connect(func() -> void: request_rank_up(node.skill))
			node.selected.connect(_on_node_selected)
			node.slot_assign_requested.connect(request_slot_assign)
			row.add_child(node)
			nodes[skill.id] = node
		var lock := Label.new()
		lock.theme_type_variation = &"MutedLabel"
		lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lock)
		_lock_labels[category] = lock
	if state.skills.is_empty():
		var empty := Label.new()
		empty.theme_type_variation = &"MutedLabel"
		empty.text = "Noch keine Skills (kommen mit AP5)."
		_rows.add_child(empty)


func _apply_states() -> void:
	for id: StringName in nodes:
		var node := nodes[id]
		node.apply_state(state, bar_skills.find(node.skill))
	_show_details()


func _on_node_selected(node: SkillNode) -> void:
	selected_skill = node.skill
	_show_details()


func _show_details() -> void:
	var skill := selected_skill
	_rank_button.disabled = skill == null or not state.can_rank_up(skill)
	for button in _assign_buttons:
		button.disabled = skill == null or state.get_rank(skill) <= 0
	if skill == null:
		_details.text = (
			"[color=%s]Skill wählen, um Details zu sehen.[/color]" % UiTheme.hex(UiTheme.TEXT_MUTED)
		)
		return
	var lines := PackedStringArray()
	(
		lines
		. append(
			(
				"[font_size=19][color=%s]%s[/color][/font_size]  [color=%s]%s · Rang %d/%d[/color]"
				% [
					UiTheme.hex(UiTheme.TEXT_TITLE),
					skill.display_name,
					UiTheme.hex(UiTheme.TEXT_MUTED),
					CATEGORY_NAMES.get(skill.category, ""),
					state.get_rank(skill),
					state.get_max_rank(skill),
				]
			)
		)
	)
	if not skill.description.is_empty():
		lines.append(skill.description)
	var facts := PackedStringArray()
	if skill.cost > 0.0:
		facts.append("Kosten: %d Wut" % roundi(skill.cost))
	if skill.generate > 0.0:
		facts.append("Erzeugt: %d Wut" % roundi(skill.generate))
	if skill.cooldown > 0.0:
		facts.append("Abklingzeit: %s s" % ItemText.format_value(Enums.Stat.DAMAGE, skill.cooldown))
	if skill.damage_multiplier > 0.0:
		facts.append("Schaden: %d %%" % roundi(skill.damage_multiplier * 100.0))
	if not facts.is_empty():
		lines.append("[color=%s]%s[/color]" % [UiTheme.hex(UiTheme.AFFIX), " · ".join(facts)])
	if not state.is_unlocked(skill) and state.get_rank(skill) == 0:
		lines.append(
			(
				"[color=%s]%s[/color]"
				% [UiTheme.hex(UiTheme.WORSE), state.lock_reasons.get(skill.id, "Gesperrt")]
			)
		)
	_details.text = "\n".join(lines)
