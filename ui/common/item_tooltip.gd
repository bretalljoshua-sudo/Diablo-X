class_name ItemTooltip
extends HBoxContainer
## Tooltip für Gegenstände im Stil von Diablo: rechts der Gegenstand unter der Maus mit farbigem
## Vergleich (grün besser, rot schlechter), links daneben der angelegte Gegenstand.
## Nutzt ItemText und ItemCompare aus AP4.

const WIDTH := 330.0
const MARGIN := 12.0

## Zuletzt gezeigter Gegenstand (für Tests).
var shown_item: ItemInstance
var shown_compare: ItemInstance

var _item_panel: PanelContainer
var _item_text: RichTextLabel
var _equipped_panel: PanelContainer
var _equipped_text: RichTextLabel


func _init() -> void:
	name = "ItemTooltip"
	theme = UiTheme.get_theme()
	top_level = true
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	add_theme_constant_override(&"separation", 6)
	_equipped_panel = _make_panel()
	_equipped_text = _equipped_panel.get_child(0) as RichTextLabel
	add_child(_equipped_panel)
	_item_panel = _make_panel()
	_item_text = _item_panel.get_child(0) as RichTextLabel
	add_child(_item_panel)


## Zeigt item neben anchor (globales Rechteck des Feldes unter der Maus).
## compare_to = angelegter Gegenstand am selben Platz; compare = false schaltet den Vergleich ab.
func show_item(
	item: ItemInstance,
	anchor: Rect2,
	compare_to: ItemInstance = null,
	compare: bool = true,
	hint: String = ""
) -> void:
	if item == null:
		hide_tooltip()
		return
	shown_item = item
	shown_compare = compare_to if compare else null
	_item_text.text = item_bbcode(item, compare_to, compare, hint)
	_equipped_panel.visible = compare and compare_to != null and compare_to != item
	if _equipped_panel.visible:
		_equipped_text.text = (
			"[color=%s]ANGELEGT[/color]\n" % UiTheme.hex(UiTheme.TEXT_MUTED)
			+ item_bbcode(compare_to, null, false)
		)
	visible = true
	reset_size()
	_place_near.call_deferred(anchor)


func hide_tooltip() -> void:
	visible = false
	shown_item = null
	shown_compare = null


## BBCode für einen Gegenstand. Bei compare = true folgen die Vergleichszeilen gegen compare_to
## (null = leerer Platz).
static func item_bbcode(
	item: ItemInstance, compare_to: ItemInstance = null, compare: bool = false, hint: String = ""
) -> String:
	if item == null or item.base == null:
		return ""
	var lines := PackedStringArray()
	var color := UiTheme.hex(ItemText.rarity_color(item.rarity))
	lines.append(
		"[font_size=19][color=%s]%s[/color][/font_size]" % [color, item.get_display_name()]
	)
	(
		lines
		. append(
			(
				"[color=%s]%s %s · %s · Stufe %d[/color]"
				% [
					color,
					ItemText.rarity_name(item.rarity),
					item.base.display_name,
					ItemText.slot_name(item.base.slot),
					item.item_level,
				]
			)
		)
	)
	if item.base.base_stats != null and not item.base.base_stats.values.is_empty():
		lines.append("")
		for stat: Enums.Stat in item.base.base_stats.values:
			var value := item.base.base_stats.values[stat]
			lines.append(
				"[b]%s[/b] %s" % [ItemText.format_value(stat, value), ItemText.stat_name(stat)]
			)
	if not item.affixes.is_empty():
		lines.append("")
		for roll in item.affixes:
			lines.append(
				"[color=%s]◆ %s[/color]" % [UiTheme.hex(UiTheme.AFFIX), ItemText.affix_line(roll)]
			)
	if item.aspect != null:
		lines.append("")
		lines.append(
			(
				"[color=%s][i]%s[/i][/color]"
				% [UiTheme.hex(UiTheme.ASPECT), ItemText.aspect_text(item.aspect)]
			)
		)
	if compare:
		lines.append("")
		lines.append_array(compare_bbcode_lines(compare_to, item))
	lines.append("")
	lines.append(
		(
			"[color=%s]Verkaufswert: %d Gold[/color]"
			% [UiTheme.hex(UiTheme.GOLD), ItemValue.sell_value(item)]
		)
	)
	if not hint.is_empty():
		lines.append("[color=%s]%s[/color]" % [UiTheme.hex(UiTheme.TEXT_MUTED), hint])
	return "\n".join(lines)


## Vergleichszeilen: grün mit ▲ für besser, rot mit ▼ für schlechter.
static func compare_bbcode_lines(
	current: ItemInstance, candidate: ItemInstance
) -> PackedStringArray:
	var lines := PackedStringArray()
	if current == candidate:
		return lines
	var header := (
		"Im Vergleich zu: %s" % current.get_display_name() if current != null else "Platz ist leer"
	)
	lines.append("[color=%s]%s[/color]" % [UiTheme.hex(UiTheme.TEXT_MUTED), header])
	var entries := ItemCompare.lines(current, candidate)
	if entries.is_empty():
		lines.append("[color=%s]Gleiche Werte[/color]" % UiTheme.hex(UiTheme.TEXT_MUTED))
	for entry in entries:
		var better: bool = entry["better"]
		(
			lines
			. append(
				(
					"[color=%s]%s %s[/color]"
					% [
						UiTheme.hex(UiTheme.BETTER if better else UiTheme.WORSE),
						"▲" if better else "▼",
						entry["text"],
					]
				)
			)
		)
	return lines


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		&"panel", UiTheme.panel_style(Color(0.025, 0.02, 0.018, 0.97), UiTheme.BORDER, 1)
	)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size = Vector2(WIDTH, 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(text)
	return panel


func _place_near(anchor: Rect2) -> void:
	var viewport_size := get_viewport_rect().size
	var tip_size := get_combined_minimum_size()
	size = tip_size
	var pos := Vector2(anchor.position.x - tip_size.x - MARGIN, anchor.position.y)
	if pos.x < MARGIN:
		pos.x = anchor.end.x + MARGIN
	pos.x = clampf(pos.x, MARGIN, maxf(viewport_size.x - tip_size.x - MARGIN, MARGIN))
	pos.y = clampf(pos.y, MARGIN, maxf(viewport_size.y - tip_size.y - MARGIN, MARGIN))
	global_position = pos
