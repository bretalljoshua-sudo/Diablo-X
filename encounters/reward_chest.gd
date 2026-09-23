class_name RewardChest
extends Node3D
## Belohnungstruhe im Bossraum. Erscheint nach dem Sieg und öffnet sich, sobald die Spielerfigur
## davor steht: Beute aus BossDef.chest_table (AP4) fällt im Halbkreis davor, dazu Licht und Klang.

signal opened(chest: RewardChest)

const PROP_SCENE := "res://assets/props/chest.tscn"
const OPEN_RANGE := 2.4
const GLOW_COLOR := Color(1.0, 0.78, 0.35)

@export var table: LootTable
@export var rolls: int = 2
@export var item_level: int = 1

var is_open: bool = false
## Gegenstände, die beim Öffnen gefallen sind (für Tests).
var dropped: Array[ItemInstance] = []

var _visual: Node3D
var _light: OmniLight3D
var _loot_counter: int = 0


func _ready() -> void:
	if ResourceLoader.exists(PROP_SCENE):
		_visual = (load(PROP_SCENE) as PackedScene).instantiate() as Node3D
	else:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.4, 0.9, 1.0)
		box.mesh = mesh
		box.position.y = 0.45
		_visual = box
	add_child(_visual)
	_light = OmniLight3D.new()
	_light.light_color = GLOW_COLOR
	_light.light_energy = 1.2
	_light.omni_range = 5.0
	_light.position = Vector3(0, 1.4, 0)
	add_child(_light)
	# Kurz aus dem Boden steigen.
	_visual.position.y = -1.2
	create_tween().tween_property(_visual, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_BACK)


func _physics_process(_delta: float) -> void:
	if is_open or not is_instance_valid(Game.player):
		return
	if (
		Components.is_alive(Game.player)
		and _flat_distance(Game.player.global_position) < OPEN_RANGE
	):
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	set_physics_process(false)
	var parent := get_parent()
	var front := global_transform.basis.z
	var count := 0
	for roll in maxi(rolls, 1):
		_loot_counter += 1
		var rng := Rng.stream(&"reward_chest", hash([get_instance_id(), _loot_counter]))
		var items := Loot.roll_drop(table, item_level, rng)
		for item in items:
			var angle := (count - 1.5) * 0.45
			var offset := front.rotated(Vector3.UP, angle) * 1.8
			GroundItem.spawn_item(parent, item, global_position + offset)
			EventBus.loot_dropped.emit(item, global_position + offset)
			dropped.append(item)
			count += 1
		var gold := Loot.roll_gold(table, item_level, rng)
		if gold > 0:
			var gold_offset := front.rotated(Vector3.UP, -1.2 + roll * 2.4) * 1.5
			GroundItem.spawn_gold(parent, gold, global_position + gold_offset)
	GameSounds.play_at(GameSounds.LOOT_DROP_LEGENDARY, global_position, self)
	EncounterFx.spawn(&"level_up", global_position)
	var tween := create_tween()
	tween.tween_property(_light, "light_energy", 3.0, 0.15)
	tween.tween_property(_light, "light_energy", 0.6, 1.2)
	opened.emit(self)


func _flat_distance(point: Vector3) -> float:
	var offset := point - global_position
	return Vector2(offset.x, offset.z).length()
