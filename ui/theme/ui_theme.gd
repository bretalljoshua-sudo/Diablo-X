class_name UiTheme
extends RefCounted
## Das Theme der Oberfläche: dunkler Stein, Bronze-Rahmen, gedämpftes Gold.
## Wird im Code erzeugt (keine Schriftdateien nötig) und einmal zwischengespeichert.
## Schriften und Rahmen-Texturen kann AP8 später über ein eigenes Theme ersetzen.

const BACKGROUND := Color(0.055, 0.047, 0.043, 0.95)
const BACKGROUND_LIGHT := Color(0.11, 0.095, 0.085, 0.97)
const SLOT_BACKGROUND := Color(0.035, 0.03, 0.028, 0.95)
const BORDER := Color(0.42, 0.33, 0.21)
const BORDER_BRIGHT := Color(0.78, 0.62, 0.36)
const TEXT := Color(0.86, 0.82, 0.74)
const TEXT_MUTED := Color(0.55, 0.52, 0.47)
const TEXT_TITLE := Color(0.9, 0.76, 0.5)
const GOLD := Color(0.95, 0.8, 0.35)
const BETTER := Color(0.4, 0.9, 0.4)
const WORSE := Color(0.95, 0.35, 0.3)
const AFFIX := Color(0.62, 0.7, 0.95)
const ASPECT := Color(1.0, 0.6, 0.25)
const LIFE := Color(0.75, 0.06, 0.05)
const FURY := Color(0.95, 0.42, 0.06)
const EXPERIENCE := Color(0.78, 0.62, 0.3)
const LOCKED := Color(0.35, 0.33, 0.3)
const HIGHLIGHT := Color(1.0, 0.88, 0.55, 0.35)

const FONT_SIZE := 16
const FONT_SIZE_SMALL := 13
const FONT_SIZE_TITLE := 22

static var _theme: Theme


## Das gemeinsame Theme aller UI-Fenster.
static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## Farbe als BBCode-Hex für RichTextLabel.
static func hex(color: Color) -> String:
	return "#" + color.to_html(false)


static func panel_style(
	background: Color = BACKGROUND, border: Color = BORDER, border_width: int = 2
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(12)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 8
	style.anti_aliasing = true
	return style


static func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE

	theme.set_stylebox(&"panel", &"PanelContainer", panel_style())
	theme.set_stylebox(&"panel", &"Panel", panel_style())
	theme.set_stylebox(
		&"panel", &"TooltipPanel", panel_style(Color(0.03, 0.025, 0.022, 0.97), BORDER, 1)
	)
	theme.set_color(&"font_color", &"TooltipLabel", TEXT)

	theme.set_color(&"font_color", &"Label", TEXT)
	theme.set_color(&"font_outline_color", &"Label", Color(0, 0, 0, 0.9))
	theme.set_constant(&"outline_size", &"Label", 3)
	theme.set_color(&"default_color", &"RichTextLabel", TEXT)

	# Überschriften der Fenster.
	theme.set_type_variation(&"TitleLabel", &"Label")
	theme.set_color(&"font_color", &"TitleLabel", TEXT_TITLE)
	theme.set_font_size(&"font_size", &"TitleLabel", FONT_SIZE_TITLE)
	theme.set_type_variation(&"MutedLabel", &"Label")
	theme.set_color(&"font_color", &"MutedLabel", TEXT_MUTED)
	theme.set_font_size(&"font_size", &"MutedLabel", FONT_SIZE_SMALL)
	theme.set_type_variation(&"GoldLabel", &"Label")
	theme.set_color(&"font_color", &"GoldLabel", GOLD)

	var normal := _button_style(Color(0.13, 0.1, 0.085), BORDER)
	var hover := _button_style(Color(0.2, 0.15, 0.11), BORDER_BRIGHT)
	var pressed := _button_style(Color(0.08, 0.065, 0.055), BORDER_BRIGHT)
	var disabled := _button_style(Color(0.08, 0.075, 0.07), Color(0.25, 0.22, 0.18))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = BORDER_BRIGHT
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(2)
	for type: StringName in [&"Button", &"OptionButton", &"CheckButton", &"CheckBox"]:
		theme.set_stylebox(&"normal", type, normal)
		theme.set_stylebox(&"hover", type, hover)
		theme.set_stylebox(&"pressed", type, pressed)
		theme.set_stylebox(&"hover_pressed", type, pressed)
		theme.set_stylebox(&"disabled", type, disabled)
		theme.set_stylebox(&"focus", type, focus)
		theme.set_color(&"font_color", type, TEXT)
		theme.set_color(&"font_hover_color", type, TEXT_TITLE)
		theme.set_color(&"font_pressed_color", type, GOLD)
		theme.set_color(&"font_focus_color", type, TEXT_TITLE)
		theme.set_color(&"font_disabled_color", type, TEXT_MUTED)

	# Flache Knöpfe (Schließen-Kreuz, Kopfzeilen).
	theme.set_type_variation(&"FlatButton", &"Button")
	var flat := StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		theme.set_stylebox(state, &"FlatButton", flat)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.02, 0.02, 0.02, 0.9)
	bar_bg.border_color = BORDER
	bar_bg.set_border_width_all(1)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = EXPERIENCE
	theme.set_stylebox(&"background", &"ProgressBar", bar_bg)
	theme.set_stylebox(&"fill", &"ProgressBar", bar_fill)

	var slider := StyleBoxFlat.new()
	slider.bg_color = Color(0.03, 0.03, 0.03)
	slider.border_color = BORDER
	slider.set_border_width_all(1)
	slider.content_margin_top = 3
	slider.content_margin_bottom = 3
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = BORDER_BRIGHT.darkened(0.3)
	slider_fill.content_margin_top = 3
	slider_fill.content_margin_bottom = 3
	theme.set_stylebox(&"slider", &"HSlider", slider)
	theme.set_stylebox(&"grabber_area", &"HSlider", slider_fill)
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", slider_fill)

	var tab_selected := _button_style(BACKGROUND_LIGHT, BORDER_BRIGHT)
	var tab_unselected := _button_style(BACKGROUND, BORDER)
	theme.set_stylebox(&"tab_selected", &"TabContainer", tab_selected)
	theme.set_stylebox(&"tab_unselected", &"TabContainer", tab_unselected)
	theme.set_stylebox(&"tab_hovered", &"TabContainer", hover)
	theme.set_stylebox(&"tab_focus", &"TabContainer", focus)
	theme.set_stylebox(&"panel", &"TabContainer", panel_style(BACKGROUND_LIGHT, BORDER, 1))
	theme.set_color(&"font_selected_color", &"TabContainer", TEXT_TITLE)
	theme.set_color(&"font_unselected_color", &"TabContainer", TEXT_MUTED)

	var separator := StyleBoxLine.new()
	separator.color = BORDER
	separator.thickness = 1
	theme.set_stylebox(&"separator", &"HSeparator", separator)
	return theme
