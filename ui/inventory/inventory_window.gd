class_name InventoryWindow
extends UiWindow
## Fenster „Charakter und Inventar“ (Taste I): Ausrüstungsplätze um die Figurvorschau,
## Werte, Inventar-Raster und Gold. Arbeitet direkt mit Inventory und Equipment aus AP4.
##
## Maus: Rechtsklick auf einen Gegenstand legt ihn an (beim Händler: verkaufen), Rechtsklick auf
## einen Platz legt ab. Linksklick nimmt auf, Linksklick auf Raster oder Platz legt ab.
## Tastatur: Pfeiltasten, Enter wie Rechtsklick, Leertaste wie Linksklick.

const LEFT_SLOTS: Array[Enums.Slot] = [
	Enums.Slot.HELM, Enums.Slot.CHEST, Enums.Slot.GLOVES, Enums.Slot.PANTS, Enums.Slot.BOOTS
]
const RIGHT_SLOTS: Array[Enums.Slot] = [
	Enums.Slot.AMULET, Enums.Slot.RING_1, Enums.Slot.RING_2, Enums.Slot.WEAPON
]
## Werte unter der Figur, mit kurzen Namen.
const SHOWN_STATS: Dictionary[Enums.Stat, String] = {
	Enums.Stat.DAMAGE: "Schaden",
	Enums.Stat.MAX_LIFE: "Leben",
	Enums.Stat.ARMOR: "Rüstung",
	Enums.Stat.ATTACK_SPEED: "Angriffstempo",
	Enums.Stat.CRIT_CHANCE: "Krit-Chance",
	Enums.Stat.CRIT_DAMAGE: "Krit-Schaden",
	Enums.Stat.MOVE_SPEED: "Lauftempo",
	Enums.Stat.RESOURCE_MAX: "Maximale Wut",
}

var inventory: Inventory
var equipment: Equipment
## Figur, deren Werte über den Stats-Dienst gezeigt werden (meist Game.player).
var stats_owner: Node
## Gemeinsamer Tooltip, setzt GameUI.
var tooltip: ItemTooltip
## Händlerfenster: ist es offen, verkauft Rechtsklick statt anzulegen. Setzt GameUI.
var merchant: MerchantWindow

var grid: InventoryGrid
var preview: CharacterPreview
var slot_views: Dictionary[Enums.Slot, EquipmentSlot] = {}

var _stat_labels: Dictionary[Enums.Stat, Label] = {}
var _gold_label: Label
var _message_label: Label


func _init() -> void:
	super(&"inventory", "Charakter und Inventar")
	var equip_row := HBoxContainer.new()
	equip_row.add_theme_constant_override(&"separation", 10)
	equip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(equip_row)
	equip_row.add_child(_slot_column(LEFT_SLOTS))
	preview = CharacterPreview.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_row.add_child(preview)
	equip_row.add_child(_slot_column(RIGHT_SLOTS))

	var stats := GridContainer.new()
	stats.columns = 4
	stats.add_theme_constant_override(&"h_separation", 14)
	body.add_child(stats)
	for stat: Enums.Stat in SHOWN_STATS:
		var caption := Label.new()
		caption.theme_type_variation = &"MutedLabel"
		caption.text = SHOWN_STATS[stat]
		stats.add_child(caption)
		var value := Label.new()
		value.custom_minimum_size.x = 60
		stats.add_child(value)
		_stat_labels[stat] = value

	grid = InventoryGrid.new()
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.item_hovered.connect(_on_item_hovered)
	grid.hover_cleared.connect(_hide_tooltip)
	grid.item_activated.connect(activate_item)
	grid.held_item_changed.connect(_on_held_item_changed)
	body.add_child(grid)

	var bottom := HBoxContainer.new()
	body.add_child(bottom)
	_message_label = Label.new()
	_message_label.theme_type_variation = &"MutedLabel"
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_message_label)
	_gold_label = Label.new()
	_gold_label.name = "GoldLabel"
	_gold_label.theme_type_variation = &"GoldLabel"
	bottom.add_child(_gold_label)


## Verbindet das Fenster mit Inventar und Ausrüstung einer Figur.
func bind(p_inventory: Inventory, p_equipment: Equipment, p_stats_owner: Node) -> void:
	if inventory != null and inventory.changed.is_connected(refresh):
		inventory.changed.disconnect(refresh)
	if equipment != null and equipment.stats_changed.is_connected(refresh):
		equipment.stats_changed.disconnect(refresh)
	inventory = p_inventory
	equipment = p_equipment
	stats_owner = p_stats_owner
	grid.set_inventory(inventory)
	if inventory != null:
		inventory.changed.connect(refresh)
	if equipment != null:
		equipment.stats_changed.connect(refresh)
	refresh()


## Anlegen (oder beim offenen Händler verkaufen), wie ein Rechtsklick.
func activate_item(item: ItemInstance) -> bool:
	if merchant != null and merchant.is_open():
		return merchant.sell(item) > 0
	return equip_item(item)


## Legt einen Gegenstand aus dem Inventar an. slot = -1 wählt den Platz selbst.
func equip_item(item: ItemInstance, slot: int = -1) -> bool:
	if inventory == null or equipment == null or item == null:
		return false
	if Equipment.slots_for(item).is_empty():
		show_message("Dieser Gegenstand lässt sich nicht anlegen.")
		return false
	if not equipment.equip_from_inventory(inventory, item, slot):
		show_message("Kein Platz im Inventar für den abgelegten Gegenstand.")
		return false
	grid.cancel_hold()
	_hide_tooltip()
	show_message("%s angelegt." % item.get_display_name())
	return true


## Legt den Gegenstand eines Platzes ins Inventar.
func unequip_slot(slot: Enums.Slot) -> bool:
	if equipment == null or equipment.get_item(slot) == null:
		return false
	var item := equipment.get_item(slot)
	if not equipment.unequip_to_inventory(inventory, slot):
		show_message("Kein Platz im Inventar.")
		return false
	_hide_tooltip()
	show_message("%s abgelegt." % item.get_display_name())
	return true


func show_message(text: String) -> void:
	_message_label.text = text


func refresh() -> void:
	for slot: Enums.Slot in slot_views:
		slot_views[slot].set_item(equipment.get_item(slot) if equipment != null else null)
	preview.show_equipment(equipment)
	for stat: Enums.Stat in _stat_labels:
		var value := Stats.get_stat(stats_owner, stat) if stats_owner != null else 0.0
		_stat_labels[stat].text = ItemText.format_value(stat, value)
	_gold_label.text = "%s Gold" % format_gold(inventory.gold if inventory != null else 0)
	grid.queue_redraw()


## 12345 → "12.345"
static func format_gold(amount: int) -> String:
	var digits := str(absi(amount))
	var parts := PackedStringArray()
	while digits.length() > 3:
		parts.insert(0, digits.substr(digits.length() - 3))
		digits = digits.substr(0, digits.length() - 3)
	parts.insert(0, digits)
	return ("-" if amount < 0 else "") + ".".join(parts)


func _on_opened() -> void:
	refresh()
	grid.grab_focus()


func _on_closed() -> void:
	grid.cancel_hold()
	_hide_tooltip()
	_message_label.text = ""


func _slot_column(slots: Array[Enums.Slot]) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	for slot in slots:
		var view := EquipmentSlot.new(slot)
		view.pressed.connect(_on_slot_pressed.bind(slot))
		view.unequip_requested.connect(unequip_slot)
		view.slot_hovered.connect(_on_slot_hovered)
		view.slot_unhovered.connect(func(_v: EquipmentSlot) -> void: _hide_tooltip())
		column.add_child(view)
		slot_views[slot] = view
	return column


func _on_slot_pressed(slot: Enums.Slot) -> void:
	if grid.held_item != null:
		if equipment.can_equip(grid.held_item, slot):
			equip_item(grid.held_item, slot)
		else:
			show_message("Passt nicht in diesen Platz.")
		return
	unequip_slot(slot)


func _on_slot_hovered(view: EquipmentSlot) -> void:
	if tooltip == null or view.item == null:
		return
	tooltip.show_item(view.item, view.get_global_rect(), null, false, "Rechtsklick: Ablegen")


func _on_item_hovered(item: ItemInstance, rect: Rect2) -> void:
	_highlight_slots_for(item if grid.held_item == null else grid.held_item)
	if tooltip == null or grid.held_item != null:
		return
	var current: ItemInstance = null
	var slot := equipment.choose_slot(item) if equipment != null else -1
	if slot >= 0:
		current = equipment.get_item(slot as Enums.Slot)
	var hint := "Rechtsklick: Anlegen"
	if merchant != null and merchant.is_open():
		hint = "Rechtsklick: Verkaufen für %d Gold" % ItemValue.sell_value(item)
	tooltip.show_item(item, rect, current, slot >= 0, hint)


func _on_held_item_changed(item: ItemInstance) -> void:
	_highlight_slots_for(item)
	_hide_tooltip()


func _highlight_slots_for(item: ItemInstance) -> void:
	var fitting := Equipment.slots_for(item)
	for slot: Enums.Slot in slot_views:
		slot_views[slot].highlight = slot in fitting


func _hide_tooltip() -> void:
	if grid.held_item == null:
		_highlight_slots_for(null)
	if tooltip != null:
		tooltip.hide_tooltip()
