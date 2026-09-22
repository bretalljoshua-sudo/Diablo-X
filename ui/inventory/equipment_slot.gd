class_name EquipmentSlot
extends Button
## Ein Ausrüstungsplatz neben der Figurvorschau. Enter oder Linksklick: gehaltenen Gegenstand
## anlegen oder den angelegten ablegen. Rechtsklick: ablegen.

signal slot_hovered(slot_view: EquipmentSlot)
signal slot_unhovered(slot_view: EquipmentSlot)
signal unequip_requested(slot: Enums.Slot)

const SIZE := Vector2(64, 64)
const SIZE_LARGE := Vector2(64, 132)

var slot: Enums.Slot
var item: ItemInstance
## Passt der gehaltene oder überfahrene Gegenstand hierher? Dann leuchtet der Rahmen.
var highlight: bool = false:
	set(value):
		if highlight != value:
			highlight = value
			queue_redraw()


func _init(p_slot: Enums.Slot = Enums.Slot.HELM) -> void:
	slot = p_slot
	name = "Slot" + String(Enums.Slot.keys()[p_slot]).to_pascal_case()
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = SIZE_LARGE if p_slot == Enums.Slot.WEAPON else SIZE
	tooltip_text = ""
	mouse_entered.connect(func() -> void: slot_hovered.emit(self))
	mouse_exited.connect(func() -> void: slot_unhovered.emit(self))
	focus_entered.connect(func() -> void: slot_hovered.emit(self))
	focus_exited.connect(func() -> void: slot_unhovered.emit(self))


func set_item(p_item: ItemInstance) -> void:
	item = p_item
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		unequip_requested.emit(slot)
		accept_event()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, UiTheme.SLOT_BACKGROUND)
	var border := UiTheme.BORDER_BRIGHT if highlight or has_focus() else UiTheme.BORDER
	if item != null:
		ItemIcon.draw(self, rect.grow(-3.0), item)
	else:
		var glyph_size := minf(rect.size.x, rect.size.y) * 0.6
		var glyph_rect := Rect2(
			rect.get_center() - Vector2.ONE * glyph_size * 0.5, Vector2.ONE * glyph_size
		)
		ItemIcon.draw_slot_glyph(self, glyph_rect, slot, Color(UiTheme.TEXT_MUTED, 0.18), 2.0)
	draw_rect(rect, border, false, 2.0)
	if highlight:
		draw_rect(rect.grow(-2.0), UiTheme.HIGHLIGHT, false, 3.0)
