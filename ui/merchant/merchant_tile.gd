class_name MerchantTile
extends Button
## Ein Angebot im Händlerfenster: Gegenstand und Preis. Klick oder Enter kauft.

signal hovered(tile: MerchantTile)
signal unhovered
signal buy_requested(item: ItemInstance)

var item: ItemInstance


func _init(p_item: ItemInstance = null, tile_size: Vector2 = Vector2(84, 104)) -> void:
	item = p_item
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = tile_size
	mouse_entered.connect(func() -> void: hovered.emit(self))
	mouse_exited.connect(func() -> void: unhovered.emit())
	focus_entered.connect(func() -> void: hovered.emit(self))
	focus_exited.connect(func() -> void: unhovered.emit())


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		buy_requested.emit(item)
		accept_event()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, UiTheme.SLOT_BACKGROUND)
	var icon_rect := Rect2(Vector2(6, 6), Vector2(size.x - 12, size.y - 34))
	ItemIcon.draw(self, icon_rect, item)
	var font := get_theme_default_font()
	var price := "%d Gold" % ItemValue.buy_price(item)
	draw_string(
		font,
		Vector2(0, size.y - 9),
		price,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		UiTheme.FONT_SIZE_SMALL,
		UiTheme.GOLD
	)
	var hovered_now := has_focus() or is_hovered()
	draw_rect(rect, UiTheme.BORDER_BRIGHT if hovered_now else UiTheme.BORDER, false, 2.0)
