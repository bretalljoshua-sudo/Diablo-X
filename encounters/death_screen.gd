class_name DeathScreen
extends CanvasLayer
## Bildschirm nach dem Tod: „Du bist gefallen“, verlorenes Gold und zwei Wege zurück ins Spiel.
## Die Entscheidung geht über revive_requested an die Spielszene (GameSession).

## where: &"level" (am Eingang der aktuellen Ebene) oder &"village" (im Dorf).
signal revive_requested(where: StringName)

const LAYER := 20
const FADE_TIME := 0.8

var level_button: Button
var village_button: Button

var _root: Control
var _dim: ColorRect
var _detail: Label


func _init() -> void:
	name = "DeathScreen"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.12, 0.0, 0.0, 0.72)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 16)
	box.custom_minimum_size.x = 420
	center.add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Du bist gefallen"
	title.add_theme_font_size_override(&"font_size", 56)
	title.add_theme_color_override(&"font_color", Color(0.85, 0.15, 0.1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_detail)
	level_button = _button(box, "Am Eingang der Ebene erwachen", &"level")
	village_button = _button(box, "Im Dorf erwachen", &"village")


## Zeigt den Bildschirm. gold_lost = verlorenes Gold, can_revive_here = Ebenen-Knopf anbieten.
func show_screen(gold_lost: int, can_revive_here: bool = true) -> void:
	_detail.text = (
		"Verloren: %d Gold" % gold_lost if gold_lost > 0 else "Die Gruft behält nichts von dir."
	)
	level_button.visible = can_revive_here
	visible = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, FADE_TIME)
	(level_button if can_revive_here else village_button).grab_focus.call_deferred()


func hide_screen() -> void:
	visible = false


func is_showing() -> bool:
	return visible


func _button(parent: Control, text: String, where: StringName) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(func() -> void: revive_requested.emit(where))
	parent.add_child(button)
	return button
