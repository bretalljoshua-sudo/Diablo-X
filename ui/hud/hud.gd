class_name Hud
extends Control
## Das HUD: Lebenskugel links, Wut-Kugel rechts, dazwischen Erfahrung, Heiltrank, Skillleiste und
## Menüknöpfe; oben rechts die Minikarte, oben in der Mitte der Bossbalken.
## Liest alles über den EventBus (Signale siehe docs/pakete/AP7.md).

## Menüknopf gedrückt: &"inventory", &"skills", &"map" oder &"pause".
signal menu_requested(window_id: StringName)

var life_orb: ResourceOrb
var fury_orb: ResourceOrb
var skill_bar: SkillBar
var potion: PotionDisplay
var experience: ExperienceBar
var boss_bar: BossBar
var minimap: Minimap
var level_label: Label

var _skill_button: Button


func _init() -> void:
	name = "Hud"
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Abklingzeiten und Kugeln halten in der Pause an.
	process_mode = Node.PROCESS_MODE_PAUSABLE

	var bottom := HBoxContainer.new()
	bottom.name = "Bottom"
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override(&"separation", 14)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -12
	add_child(bottom)

	life_orb = ResourceOrb.new("Leben", UiTheme.LIFE)
	life_orb.name = "LifeOrb"
	bottom.add_child(life_orb)

	var center := VBoxContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.alignment = BoxContainer.ALIGNMENT_END
	center.add_theme_constant_override(&"separation", 6)
	bottom.add_child(center)
	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override(&"separation", 8)
	center.add_child(top_row)
	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "Stufe 1"
	top_row.add_child(level_label)
	experience = ExperienceBar.new()
	experience.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	experience.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(experience)
	var bar_row := HBoxContainer.new()
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_theme_constant_override(&"separation", 12)
	center.add_child(bar_row)
	potion = PotionDisplay.new()
	bar_row.add_child(potion)
	skill_bar = SkillBar.new()
	skill_bar.slot_clicked.connect(func(_slot: int) -> void: menu_requested.emit(&"skills"))
	bar_row.add_child(skill_bar)
	var menu := GridContainer.new()
	menu.columns = 2
	menu.add_theme_constant_override(&"h_separation", 4)
	menu.add_theme_constant_override(&"v_separation", 4)
	bar_row.add_child(menu)
	menu.add_child(_menu_button("Inventar", &"inventory", &"open_inventory"))
	_skill_button = _menu_button("Skills", &"skills", &"open_skills")
	menu.add_child(_skill_button)
	menu.add_child(_menu_button("Karte", &"map", &"open_map"))
	menu.add_child(_menu_button("Menü", &"pause", &"pause"))

	fury_orb = ResourceOrb.new("Wut", UiTheme.FURY)
	fury_orb.name = "FuryOrb"
	bottom.add_child(fury_orb)

	boss_bar = BossBar.new()
	boss_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss_bar.offset_top = 24
	add_child(boss_bar)

	minimap = Minimap.new()
	add_child(minimap)

	EventBus.player_health_changed.connect(life_orb.set_values)
	EventBus.resource_changed.connect(fury_orb.set_values)
	EventBus.experience_changed.connect(
		func(_c: int, _r: int, level: int) -> void: level_label.text = "Stufe %d" % level
	)
	EventBus.player_level_up.connect(
		func(level: int) -> void: level_label.text = "Stufe %d" % level
	)
	EventBus.skill_tree_changed.connect(_on_skill_tree_changed)


func _menu_button(text: String, window_id: StringName, action: StringName) -> Button:
	var button := Button.new()
	button.name = text + "Button"
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", UiTheme.FONT_SIZE_SMALL)
	var key := Settings.get_key_binding(action)
	button.tooltip_text = (
		"%s (%s)" % [text, OS.get_keycode_string(key)] if key != KEY_NONE else text
	)
	button.pressed.connect(func() -> void: menu_requested.emit(window_id))
	return button


func _on_skill_tree_changed(state: SkillTreeState) -> void:
	var points := state.points if state != null else 0
	_skill_button.text = "Skills (+%d)" % points if points > 0 else "Skills"
	_skill_button.modulate = UiTheme.GOLD.lightened(0.3) if points > 0 else Color.WHITE
