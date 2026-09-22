extends Node3D
## Hilfsfigur für AP2-Tests: Node3D mit Stats-, Health-, StatusEffects- und
## Knockback-Komponente. Aufbau über ap2_entity.gd.make().

const Self := preload("res://tests/unit/ap2_entity.gd")


static func make(stats: Dictionary = {}) -> Node3D:
	var entity: Node3D = Self.new()
	var stats_component := StatsComponent.new()
	stats_component.name = "Stats"
	stats_component.base_stats = StatBlock.from_dict(stats)
	entity.add_child(stats_component)
	var health := HealthComponent.new()
	health.name = "Health"
	entity.add_child(health)
	var effects := StatusEffectsComponent.new()
	effects.name = "StatusEffects"
	entity.add_child(effects)
	var knockback := KnockbackComponent.new()
	knockback.name = "Knockback"
	entity.add_child(knockback)
	return entity
