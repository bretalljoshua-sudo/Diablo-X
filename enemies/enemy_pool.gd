class_name EnemyPool
extends Node
## Objekt-Pool für Gegner: besiegte Gegner werden nicht gelöscht, sondern aus dem Baum
## genommen und beim nächsten acquire() desselben Typs wiederverwendet. Das spart das teure
## Erzeugen von Szenen und Modellen mitten im Kampf.

const ENEMY_SCENE_PATH := "res://enemies/enemy.tscn"

static var _enemy_scene: PackedScene

var _free: Dictionary[StringName, Array] = {}
var _active: Array[Enemy] = []
var _created: int = 0


static func instantiate_enemy() -> Enemy:
	if _enemy_scene == null:
		_enemy_scene = load(ENEMY_SCENE_PATH) as PackedScene
	return _enemy_scene.instantiate() as Enemy


## Holt einen Gegner des Typs (wiederverwendet oder neu), hängt ihn unter parent an position
## und richtet ihn ein. affixes nicht leer = Elite-Gegner.
func acquire(
	type: EnemyType,
	parent: Node,
	position: Vector3,
	level: int = 1,
	affixes: Array[EliteAffix] = [],
	summon: bool = false
) -> Enemy:
	var enemy: Enemy = null
	var free_list: Array = _free.get(type.id, [])
	while enemy == null and not free_list.is_empty():
		var candidate: Variant = free_list.pop_back()
		if is_instance_valid(candidate):
			enemy = candidate as Enemy
	if enemy == null:
		enemy = instantiate_enemy()
		_created += 1
	enemy.pool = self
	enemy.position = position
	parent.add_child(enemy)
	enemy.global_position = position
	enemy.setup(type, level, affixes, summon)
	_active.append(enemy)
	return enemy


## Nimmt einen Gegner zurück (nach dem Tod oder beim Aufräumen der Ebene).
func release(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	_active.erase(enemy)
	enemy.telegraph.hide_telegraph()
	enemy.elite.clear()
	enemy.set_physics_process(false)
	var parent := enemy.get_parent()
	if parent != null:
		parent.remove_child(enemy)
	var id: StringName = enemy.type.id if enemy.type != null else &""
	if not _free.has(id):
		_free[id] = []
	if not _free[id].has(enemy):
		_free[id].append(enemy)


## Nimmt alle aktiven Gegner zurück.
func release_all() -> void:
	for enemy in _active.duplicate():
		release(enemy)
	_active.clear()


## Legt count Gegner eines Typs vorab an (zum Beispiel beim Laden einer Ebene). Modell und
## Werte bekommen sie erst beim acquire().
func prewarm(type: EnemyType, count: int) -> void:
	if not _free.has(type.id):
		_free[type.id] = []
	for i in count:
		_free[type.id].append(instantiate_enemy())
		_created += 1


func get_active() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for enemy in _active:
		if is_instance_valid(enemy) and enemy.is_inside_tree():
			alive.append(enemy)
	_active = alive
	return alive.duplicate()


func active_count() -> int:
	return get_active().size()


func free_count(type_id: StringName = &"") -> int:
	if type_id != &"":
		return (_free.get(type_id, []) as Array).size()
	var total := 0
	for list: Array in _free.values():
		total += list.size()
	return total


## Anzahl insgesamt erzeugter Gegner-Szenen (für Tests: Pool verhindert Neuerzeugung).
func created_count() -> int:
	return _created


func _exit_tree() -> void:
	# Freie Gegner hängen nicht im Baum und würden sonst als verwaiste Knoten übrig bleiben.
	for list: Array in _free.values():
		for enemy: Variant in list:
			if is_instance_valid(enemy):
				(enemy as Node).free()
	_free.clear()
