extends Node3D
## Testszene für AP4 „Beute und Gegenstände“. Start: --scene=loot_test
##
## Linksklick auf den Boden lässt Beute fallen, Linksklick auf Beute sammelt sie auf.
## 1/2: Gegnerstufe −/+ · 3: Beutetabelle wechseln · 4: 1.000 Drops simulieren
## I: bessere Gegenstände aus dem Inventar anlegen · Q: Inventar verkaufen

const TABLES: Array[StringName] = [&"normal", &"elite", &"boss", &"chest"]
const SIMULATION_DROPS := 1000
const PICK_RAY_LENGTH := 200.0

var level: int = 1
var table_index: int = 2
var last_message: String = ""

var _drop_counter: int = 0

@onready var player: Node3D = $Player
@onready var inventory: Inventory = $Player/Inventory
@onready var equipment: Equipment = $Player/Equipment
@onready var _info: Label = $Hud/Info
@onready var _drops: Node3D = $Drops


func _ready() -> void:
	Game.player = player
	var db := ItemDatabase.get_default()
	print(
		(
			"Beute-Testszene: %d Grundformen, %d Affixe, %d Aspekte, %d einzigartige"
			% [db.bases.size(), db.affixes.size(), db.aspects.size(), db.uniques.size()]
		)
	)
	inventory.changed.connect(_refresh)
	equipment.stats_changed.connect(_refresh)
	# Startbeute, damit gleich etwas am Boden liegt.
	for spot: Vector3 in [Vector3(-3, 0, 2), Vector3(3, 0, 2), Vector3(0, 0, -3)]:
		drop_loot(spot)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"primary_action"):
		_handle_click()
	elif event.is_action_pressed(&"skill_1"):
		level = maxi(level - 1, 1)
	elif event.is_action_pressed(&"skill_2"):
		level = mini(level + 1, 10)
	elif event.is_action_pressed(&"skill_3"):
		table_index = (table_index + 1) % TABLES.size()
	elif event.is_action_pressed(&"skill_4"):
		last_message = simulate(SIMULATION_DROPS)
	elif event.is_action_pressed(&"open_inventory"):
		last_message = "%d Gegenstände angelegt" % equip_upgrades()
	elif event.is_action_pressed(&"potion"):
		last_message = "Für %d Gold verkauft" % sell_all()
	else:
		return
	get_viewport().set_input_as_handled()
	_refresh()


func current_table() -> LootTable:
	return Loot.get_table(TABLES[table_index])


## Lässt einen Drop der aktuellen Tabelle an position fallen.
func drop_loot(position: Vector3) -> Array[GroundItem]:
	_drop_counter += 1
	var rng := Rng.stream(&"loot_test", _drop_counter)
	return Loot.drop_at(current_table(), level, rng, position, _drops)


## Sammelt alles am Boden auf, liefert die Anzahl.
func pick_up_all() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(GroundItem.GROUP):
		var ground := node as GroundItem
		if ground != null and ground.try_pick_up(inventory):
			count += 1
	return count


## Legt jeden Gegenstand aus dem Inventar an, der laut ItemCompare besser ist.
func equip_upgrades() -> int:
	var count := 0
	for item in inventory.get_items():
		var slot := equipment.choose_slot(item)
		if slot < 0:
			continue
		if ItemCompare.is_upgrade(equipment.get_item(slot), item):
			if equipment.equip_from_inventory(inventory, item, slot):
				count += 1
	return count


func sell_all() -> int:
	var total := 0
	for item in inventory.get_items():
		total += inventory.sell_item(item)
	return total


## Würfelt count Drops der aktuellen Tabelle und liefert die Seltenheitsverteilung als Text.
func simulate(count: int) -> String:
	var counts: Dictionary[Enums.Rarity, int] = {}
	var total := 0
	var rng := Rng.stream(&"loot_test_sim", level)
	for i in count:
		for item in Loot.roll_drop(current_table(), level, rng):
			counts[item.rarity] = counts.get(item.rarity, 0) + 1
			total += 1
	var parts := PackedStringArray()
	for rarity: Enums.Rarity in Enums.Rarity.values():
		var share := 100.0 * float(counts.get(rarity, 0)) / maxf(total, 1)
		parts.append("%s %.1f %%" % [ItemText.rarity_name(rarity), share])
	return "%d Drops, %d Gegenstände: %s" % [count, total, ", ".join(parts)]


func _handle_click() -> void:
	var rig := CameraRig.get_active()
	if rig == null or rig.camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var from := rig.camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(
		from, from + rig.camera.project_ray_normal(mouse) * PICK_RAY_LENGTH
	)
	query.collide_with_areas = true
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.LOOT
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.get("collider") is GroundItem:
		var ground := hit["collider"] as GroundItem
		var item := ground.item
		if ground.try_pick_up(inventory):
			last_message = _describe_pickup(item)
		else:
			last_message = "Kein Platz im Inventar"
		return
	var point := rig.screen_to_ground(mouse)
	if point != Vector3.INF:
		drop_loot(point)


func _describe_pickup(item: ItemInstance) -> String:
	if item == null:
		return "Gold aufgesammelt"
	var lines := ItemText.tooltip_lines(item)
	var current := equipment.get_item(maxi(equipment.choose_slot(item), 0))
	for line in ItemCompare.lines(current, item):
		lines.append("  %s %s" % ["▲" if line["better"] else "▼", line["text"]])
	return "\n".join(lines)


func _refresh() -> void:
	if _info == null:
		return
	var lines := PackedStringArray()
	lines.append(
		(
			"Stufe %d · Tabelle %s · Gold %d · Inventar %d Gegenstände"
			% [level, TABLES[table_index], inventory.gold, inventory.get_item_count()]
		)
	)
	var stat_parts := PackedStringArray()
	for stat: Enums.Stat in [
		Enums.Stat.DAMAGE, Enums.Stat.MAX_LIFE, Enums.Stat.ARMOR, Enums.Stat.CRIT_CHANCE
	]:
		stat_parts.append(
			(
				"%s %s"
				% [
					ItemText.stat_name(stat),
					ItemText.format_value(stat, Stats.get_stat(player, stat))
				]
			)
		)
	lines.append("Werte: " + " · ".join(stat_parts))
	var equipped := equipment.get_equipped()
	for slot: Enums.Slot in equipped:
		lines.append("  %s: %s" % [ItemText.slot_name(slot), equipped[slot].get_display_name()])
	if not last_message.is_empty():
		lines.append("")
		lines.append(last_message)
	_info.text = "\n".join(lines)
