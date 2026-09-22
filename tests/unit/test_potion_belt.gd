extends GutTest
## Heiltrank mit Ladungen (AP2).

const Entity := preload("res://tests/unit/ap2_entity.gd")

var _owner: Node3D
var _belt: PotionBelt


func before_each() -> void:
	_owner = Entity.make({Enums.Stat.MAX_LIFE: 200.0})
	_belt = PotionBelt.new()
	_belt.max_charges = 3
	_belt.heal_ratio = 0.25
	_belt.cooldown = 1.0
	_belt.kills_per_charge = 2
	_owner.add_child(_belt)
	add_child_autofree(_owner)


func test_drink_heals_share_of_max_life_and_uses_charge() -> void:
	var health := Components.health(_owner)
	health.take_damage(150.0)
	assert_true(_belt.drink())
	assert_eq(health.current, 100.0)
	assert_eq(_belt.charges, 2)


func test_cannot_drink_at_full_life_or_during_cooldown() -> void:
	assert_false(_belt.drink(), "volles Leben")
	Components.health(_owner).take_damage(150.0)
	assert_true(_belt.drink())
	assert_false(_belt.drink(), "Abklingzeit")
	_belt._physics_process(1.1)
	assert_true(_belt.drink())


func test_no_charges_left() -> void:
	var health := Components.health(_owner)
	health.take_damage(190.0)
	for i in 3:
		assert_true(_belt.drink())
		_belt._physics_process(2.0)
	health.take_damage(100.0)
	assert_eq(_belt.charges, 0)
	assert_false(_belt.drink())


func test_kills_refill_charges() -> void:
	var health := Components.health(_owner)
	health.take_damage(190.0)
	_belt.drink()
	assert_eq(_belt.charges, 2)
	var victim := autofree(Node3D.new()) as Node3D
	EventBus.entity_died.emit(victim, _owner)
	assert_eq(_belt.charges, 2)
	assert_almost_eq(_belt.progress, 0.5, 0.001)
	EventBus.entity_died.emit(victim, _owner)
	assert_eq(_belt.charges, 3)
	assert_eq(_belt.progress, 0.0)
	EventBus.entity_died.emit(victim, _owner)
	assert_eq(_belt.charges, 3, "nie über das Maximum")


func test_kills_by_others_do_not_count() -> void:
	Components.health(_owner).take_damage(100.0)
	_belt.drink()
	var victim := autofree(Node3D.new()) as Node3D
	EventBus.entity_died.emit(victim, null)
	EventBus.entity_died.emit(victim, victim)
	assert_eq(_belt.progress, 0.0)


func test_dead_cannot_drink() -> void:
	Components.health(_owner).take_damage(500.0)
	assert_false(_belt.drink())
