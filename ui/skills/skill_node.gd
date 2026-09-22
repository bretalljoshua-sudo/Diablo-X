class_name SkillNode
extends Button
## Ein Skill im Skillbaum. Klick oder Enter: Rang erhöhen. Mit Fokus legen die Tasten 1 bis 4
## den Skill auf die Leiste, Rechtsklick auf die rechte Maustaste.

signal selected(node: SkillNode)
signal slot_assign_requested(slot: int, skill: SkillDef)

const SIZE := Vector2(76, 92)
const SLOT_ACTIONS: Array[StringName] = [&"skill_1", &"skill_2", &"skill_3", &"skill_4"]

var skill: SkillDef
var rank: int = 0
var max_rank: int = 1
var unlocked: bool = false
var can_rank_up: bool = false
## Platz auf der Skillleiste (-1 = nicht auf der Leiste).
var bar_slot: int = -1


func _init(p_skill: SkillDef = null) -> void:
	skill = p_skill
	name = "Skill_" + String(p_skill.id) if p_skill != null else "Skill"
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = SIZE
	mouse_entered.connect(func() -> void: selected.emit(self))
	focus_entered.connect(func() -> void: selected.emit(self))


func apply_state(state: SkillTreeState, p_bar_slot: int) -> void:
	rank = state.get_rank(skill)
	max_rank = state.get_max_rank(skill)
	unlocked = state.is_unlocked(skill)
	can_rank_up = state.can_rank_up(skill)
	bar_slot = p_bar_slot
	tooltip_text = ""
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if rank <= 0:
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		slot_assign_requested.emit(1, skill)
		accept_event()
		return
	for i in SLOT_ACTIONS.size():
		if event.is_action_pressed(SLOT_ACTIONS[i]):
			slot_assign_requested.emit(SkillBar.FIRST_KEY_SLOT + i, skill)
			accept_event()
			return


func _draw() -> void:
	var icon_size := SIZE.x - 16.0
	var icon_rect := Rect2(Vector2((size.x - icon_size) * 0.5, 4), Vector2(icon_size, icon_size))
	var center := icon_rect.get_center()
	var radius := icon_size * 0.5
	var ring := UiTheme.BORDER
	if can_rank_up:
		ring = UiTheme.GOLD
	elif rank > 0:
		ring = UiTheme.BORDER_BRIGHT
	if not unlocked and rank == 0:
		ring = UiTheme.LOCKED
	if has_focus() or is_hovered():
		ring = ring.lightened(0.35)
	draw_circle(center, radius, UiTheme.SLOT_BACKGROUND)
	if skill != null and skill.icon != null:
		var tint := Color.WHITE if unlocked or rank > 0 else Color(0.35, 0.35, 0.35)
		draw_texture_rect(skill.icon, icon_rect.grow(-6.0), false, tint)
	else:
		draw_circle(center, radius - 5.0, SkillBar.category_color(skill).darkened(0.55))
		var initials := SkillBar.initials(skill)
		var font := get_theme_default_font()
		var text_color := UiTheme.TEXT if unlocked or rank > 0 else UiTheme.TEXT_MUTED
		draw_string(
			font,
			Vector2(icon_rect.position.x, center.y + 8),
			initials,
			HORIZONTAL_ALIGNMENT_CENTER,
			icon_rect.size.x,
			22,
			text_color
		)
	draw_arc(center, radius, 0.0, TAU, 32, ring, 3.0 if can_rank_up else 2.0, true)
	if can_rank_up:
		draw_arc(center, radius + 3.0, 0.0, TAU, 32, Color(UiTheme.GOLD, 0.35), 2.0, true)
	var font := get_theme_default_font()
	draw_string(
		font,
		Vector2(0, size.y - 6),
		"%d/%d" % [rank, max_rank],
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		UiTheme.FONT_SIZE_SMALL,
		UiTheme.GOLD if rank > 0 else UiTheme.TEXT_MUTED
	)
	if bar_slot >= 0:
		var badge := Rect2(Vector2(size.x - 24, 2), Vector2(22, 18))
		draw_rect(badge, Color(0, 0, 0, 0.8))
		draw_rect(badge, UiTheme.BORDER_BRIGHT, false, 1.0)
		draw_string(
			font,
			badge.position + Vector2(0, 14),
			SkillBar.SLOT_LABELS[bar_slot],
			HORIZONTAL_ALIGNMENT_CENTER,
			badge.size.x,
			11,
			UiTheme.TEXT
		)
