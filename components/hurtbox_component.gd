class_name HurtboxComponent
extends Area3D
## Trefferfläche einer Figur. Angriffe (HitboxComponent, MeleeQuery) und die Mausauswahl
## suchen nach diesen Flächen. Braucht eine CollisionShape3D als Kind.

const GROUP := &"hurtboxes"

@export var faction: Enums.Faction = Enums.Faction.ENEMY
## Ungefährer Radius der Figur in Metern, für Nahkampf-Reichweite und Mausauswahl.
@export var radius: float = 0.5

## Die Figur, der diese Fläche gehört (der Elternknoten).
var entity: Node3D


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = PhysicsLayers.HURTBOX
	collision_mask = 0
	monitoring = false
	monitorable = true
	input_ray_pickable = false
	entity = get_parent() as Node3D
	var health := Components.health(entity)
	if health != null:
		health.died.connect(func(_killer: Node3D) -> void: set_enabled(false))
		health.revived.connect(func() -> void: set_enabled(true))


func is_alive() -> bool:
	return Components.is_alive(entity)


func is_hostile_to(other: Enums.Faction) -> bool:
	return faction != other


## Schaltet die Fläche für Treffer und Mausauswahl an oder aus (zum Beispiel beim Tod).
func set_enabled(enabled: bool) -> void:
	set_deferred(&"monitorable", enabled)
	collision_layer = PhysicsLayers.HURTBOX if enabled else 0
