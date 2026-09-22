class_name UiSimTest
extends SimTest
## Grundlage für die UI-Simulationstests (AP7): lädt die Testszene ui_test und bedient die
## Oberfläche wie ein Spieler mit echten Maus- und Tastatur-Ereignissen.

var scene: Node
var ui: GameUI


func before_all() -> void:
	# Die Oberfläche von GUT liegt über allem und würde Mausklicks abfangen.
	_set_gut_gui_visible(false)


func after_all() -> void:
	_set_gut_gui_visible(true)


func before_each() -> void:
	scene = await load_scene("ui_test")
	ui = scene.get(&"ui") as GameUI
	await wait_process_frames(2)


func after_each() -> void:
	get_tree().paused = false
	Settings.reset_key_bindings()


## Bewegt die Maus an eine Stelle (Bildschirmkoordinaten der UI).
func mouse_move(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	get_viewport().push_input(motion, true)
	await wait_process_frames(1)


## Klickt an eine Stelle: Maus hin, drücken, loslassen.
func click(position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	await mouse_move(position)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = button
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else 0
		get_viewport().push_input(event, true)
		await wait_process_frames(1)


func click_control(control: Control, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	await click(control.get_global_rect().get_center(), button)


## Drückt eine Taste (physisch), wie auf der Tastatur.
func press_key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await wait_process_frames(1)


## Ein Gegenstand je Platz aus den echten Grundformen (Ringe zweimal). tier 1 ist die
## schwächste Grundform eines Platzes, höhere tier nehmen bessere (so weit vorhanden).
func make_item_set(rarity: Enums.Rarity, tier: int) -> Array[ItemInstance]:
	var db := ItemDatabase.get_default()
	var result: Array[ItemInstance] = []
	for slot: Enums.Slot in Enums.Slot.values():
		var base_slot := Enums.Slot.RING_1 if slot == Enums.Slot.RING_2 else slot
		var candidates := db.bases.filter(func(b: ItemBase) -> bool: return b.slot == base_slot)
		if candidates.is_empty():
			continue
		# Schwache Grundformen zuerst: tier 1 = Stufe-1-Form, höher = bessere Form.
		candidates.sort_custom(
			func(a: ItemBase, b: ItemBase) -> bool: return a.min_level < b.min_level
		)
		var item := ItemInstance.new()
		item.base = candidates[mini(tier - 1, candidates.size() - 1)]
		item.rarity = rarity
		item.item_level = tier * 3
		result.append(item)
	return result


func player_inventory() -> Inventory:
	return Inventory.find_on(Game.player)


func player_equipment() -> Equipment:
	return Equipment.find_on(Game.player)


func _set_gut_gui_visible(value: bool) -> void:
	var layer := get_tree().root.get_node_or_null("GutRunner/GutLayer") as CanvasLayer
	if layer != null:
		layer.visible = value
