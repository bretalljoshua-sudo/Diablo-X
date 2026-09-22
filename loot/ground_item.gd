class_name GroundItem
extends Area3D
## PLATZHALTER: Gegenstand oder Gold am Boden. Farbiger Block mit Namensschild,
## aufsammeln per Klick. Lichtsäule, Klang und Effekte baut AP1 (hört auf loot_dropped).
##
## Beim Klick wird das Inventar von Game.player verwendet (Inventory.find_on()).
## Physik-Ebene: PhysicsLayers.LOOT (Ebene 5 „loot“).

signal picked_up(ground_item: GroundItem)

const SCENE_PATH := "res://loot/ground_item.tscn"
const GROUP := &"ground_items"
const GOLD_COLOR := Color(1.0, 0.8, 0.2)

## Gegenstand am Boden, null bei reinem Gold.
var item: ItemInstance
var gold: int = 0

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _label: Label3D = $Label


## Erzeugt einen Gegenstand am Boden und hängt ihn an parent.
static func spawn_item(parent: Node, p_item: ItemInstance, position: Vector3) -> GroundItem:
	var node := (load(SCENE_PATH) as PackedScene).instantiate() as GroundItem
	node.item = p_item
	parent.add_child(node)
	node.global_position = position
	return node


static func spawn_gold(parent: Node, amount: int, position: Vector3) -> GroundItem:
	var node := (load(SCENE_PATH) as PackedScene).instantiate() as GroundItem
	node.gold = amount
	parent.add_child(node)
	node.global_position = position
	return node


func _ready() -> void:
	add_to_group(GROUP)
	var color := GOLD_COLOR
	if item != null:
		color = ItemText.rarity_color(item.rarity)
		_label.text = item.get_display_name()
	else:
		_label.text = "%d Gold" % gold
	_label.modulate = color
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = item != null and item.rarity >= Enums.Rarity.RARE
	material.emission = color
	_mesh.material_override = material


func _input_event(
	_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int
) -> void:
	if event.is_action_pressed(&"primary_action"):
		if try_pick_up(Inventory.find_on(Game.player)):
			get_viewport().set_input_as_handled()


## Legt den Inhalt ins Inventar und entfernt sich. false, wenn kein Platz ist.
func try_pick_up(inventory: Inventory) -> bool:
	if inventory == null or is_queued_for_deletion():
		return false
	if item != null:
		if not inventory.pick_up(item):
			return false
	else:
		inventory.add_gold(gold)
	picked_up.emit(self)
	queue_free()
	return true
