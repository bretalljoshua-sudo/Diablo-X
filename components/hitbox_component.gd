class_name HitboxComponent
extends Area3D
## Angriffsfläche: trifft gegnerische HurtboxComponents, die sie überlappen, solange sie
## aktiv ist. Gedacht für Geschosse, Flächenschaden und Schwünge mit eigener Form.
## Jede Aktivierung trifft ein Ziel höchstens einmal (once_per_target).
## Für einfache Nahkampfschläge ohne Physik gibt es MeleeQuery.

signal hit_landed(target: Node3D, result: DamageResult)

@export var faction: Enums.Faction = Enums.Faction.PLAYER
@export var damage: float = 10.0
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
@export var knockback: float = 0.0
@export var can_crit: bool = true
@export var once_per_target: bool = true
@export var active: bool = false:
	set = set_active

## Angreifer für HitInfo.source. Leer = Elternknoten.
var source: Node3D
var skill: SkillDef

var _already_hit: Dictionary[int, bool] = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.HURTBOX
	monitorable = false
	monitoring = true
	if source == null:
		source = get_parent() as Node3D
	area_entered.connect(_on_area_entered)


func set_active(value: bool) -> void:
	active = value
	if not value:
		return
	_already_hit.clear()
	if is_inside_tree():
		for area in get_overlapping_areas():
			try_hit(area)


## Trifft die Fläche, wenn sie eine gegnerische, lebende Hurtbox ist.
func try_hit(area: Area3D) -> DamageResult:
	var hurtbox := area as HurtboxComponent
	if (
		not active
		or hurtbox == null
		or not hurtbox.is_hostile_to(faction)
		or not hurtbox.is_alive()
	):
		return null
	var key := hurtbox.entity.get_instance_id()
	if once_per_target and _already_hit.has(key):
		return null
	_already_hit[key] = true
	var hit := HitInfo.create(source, hurtbox.entity, damage, damage_type)
	hit.knockback = knockback
	hit.can_crit = can_crit
	hit.skill = skill
	var result := Combat.apply_damage(hit)
	hit_landed.emit(hurtbox.entity, result)
	return result


func _on_area_entered(area: Area3D) -> void:
	if active:
		try_hit(area)
