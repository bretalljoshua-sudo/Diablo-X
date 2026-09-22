class_name MerchantWindow
extends UiWindow
## Händlerfenster. Öffnet sich über EventBus.merchant_opened(name, stock) zusammen mit dem Inventar.
## Kaufen: Links- oder Rechtsklick (oder Enter) auf ein Angebot. Verkaufen: Rechtsklick im Inventar.
## Preise aus ItemValue (AP4), Gold über Inventory.spend_gold()/sell_item().

const COLUMNS := 5
const TILE_SIZE := Vector2(84, 104)

var inventory: Inventory
var equipment: Equipment
var tooltip: ItemTooltip
var merchant_name: String = ""
## Angebot des Händlers. Gekaufte Gegenstände werden daraus entfernt.
var stock: Array[ItemInstance] = []

var _tiles: GridContainer
var _message_label: Label


func _init() -> void:
	super(&"merchant", "Händler")
	var hint := Label.new()
	hint.theme_type_variation = &"MutedLabel"
	hint.text = "Klick auf ein Angebot: kaufen · Rechtsklick im Inventar: verkaufen"
	body.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(COLUMNS * (TILE_SIZE.x + 6) + 10, 3 * (TILE_SIZE.y + 6))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_tiles = GridContainer.new()
	_tiles.name = "Tiles"
	_tiles.columns = COLUMNS
	_tiles.add_theme_constant_override(&"h_separation", 6)
	_tiles.add_theme_constant_override(&"v_separation", 6)
	scroll.add_child(_tiles)
	_message_label = Label.new()
	_message_label.theme_type_variation = &"MutedLabel"
	body.add_child(_message_label)


func bind(p_inventory: Inventory, p_equipment: Equipment) -> void:
	inventory = p_inventory
	equipment = p_equipment


func open_merchant(p_name: String, p_stock: Array[ItemInstance]) -> void:
	merchant_name = p_name
	stock = p_stock
	set_title(p_name if not p_name.is_empty() else "Händler")
	_message_label.text = ""
	_rebuild()
	open_window()


## Kauft einen Gegenstand aus dem Angebot. false bei zu wenig Gold oder vollem Inventar.
func buy(item: ItemInstance) -> bool:
	if inventory == null or item == null or not item in stock:
		return false
	var price := ItemValue.buy_price(item)
	if inventory.gold < price:
		_message_label.text = "Nicht genug Gold (%d benötigt)." % price
		return false
	if not inventory.has_space_for(item):
		_message_label.text = "Kein Platz im Inventar."
		return false
	inventory.spend_gold(price)
	inventory.add_item(item)
	stock.erase(item)
	_message_label.text = "%s für %d Gold gekauft." % [item.get_display_name(), price]
	EventBus.merchant_item_bought.emit(item, price)
	if tooltip != null:
		tooltip.hide_tooltip()
	_rebuild()
	return true


## Verkauft einen Gegenstand aus dem Inventar und liefert den Erlös.
func sell(item: ItemInstance) -> int:
	if inventory == null or item == null:
		return 0
	var price := inventory.sell_item(item)
	if price > 0:
		_message_label.text = "%s für %d Gold verkauft." % [item.get_display_name(), price]
		EventBus.merchant_item_sold.emit(item, price)
		if tooltip != null:
			tooltip.hide_tooltip()
	return price


func get_tile(item: ItemInstance) -> MerchantTile:
	for tile in _tiles.get_children():
		if tile is MerchantTile and (tile as MerchantTile).item == item:
			return tile
	return null


func _on_opened() -> void:
	if _tiles.get_child_count() > 0:
		(_tiles.get_child(0) as Control).grab_focus()


func _on_closed() -> void:
	if tooltip != null:
		tooltip.hide_tooltip()


func _rebuild() -> void:
	for child in _tiles.get_children():
		_tiles.remove_child(child)
		child.queue_free()
	for item in stock:
		var tile := MerchantTile.new(item, TILE_SIZE)
		tile.pressed.connect(buy.bind(item))
		tile.buy_requested.connect(buy)
		tile.hovered.connect(_on_tile_hovered)
		tile.unhovered.connect(_on_tile_unhovered)
		_tiles.add_child(tile)
	if _tiles.get_child_count() > 0 and visible:
		(_tiles.get_child(0) as Control).grab_focus()


func _on_tile_unhovered() -> void:
	if tooltip != null:
		tooltip.hide_tooltip()


func _on_tile_hovered(tile: MerchantTile) -> void:
	if tooltip == null:
		return
	var current: ItemInstance = null
	var slot := equipment.choose_slot(tile.item) if equipment != null else -1
	if slot >= 0:
		current = equipment.get_item(slot as Enums.Slot)
	var hint := "Klick: Kaufen für %d Gold" % ItemValue.buy_price(tile.item)
	tooltip.show_item(tile.item, tile.get_global_rect(), current, slot >= 0, hint)
