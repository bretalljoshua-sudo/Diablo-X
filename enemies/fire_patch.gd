class_name FirePatch
extends Node3D
## Feuerfläche der Elite-Eigenschaft „Brennend“: erst Vorwarnung, dann brennt der Boden
## für duration Sekunden. Wer darin steht, bekommt alle TICK Sekunden Feuerschaden und brennt.

const GROUP := &"enemy_hazards"
const TICK := 0.5
const POOL_META := &"fire_patch_pool"
const FIRE_COLOR := Color(1.0, 0.45, 0.05)

static var _burn_mesh: Mesh

var source: Node3D
var radius: float = 2.0
var damage_per_second: float = 5.0
var effect: StatusEffectDef
var faction: Enums.Faction = Enums.Faction.ENEMY

var _telegraph: AttackTelegraph
var _flames: MeshInstance3D
var _windup_left: float = 0.0
var _burn_left: float = 0.0
var _tick_left: float = 0.0


static func spawn(
	parent: Node, p_source: Node3D, point: Vector3, affix: EliteAffix, damage: float
) -> FirePatch:
	var patch: FirePatch = null
	var pool: Array = parent.get_meta(POOL_META, [])
	while patch == null and not pool.is_empty():
		var candidate: Variant = pool.pop_back()
		if is_instance_valid(candidate) and (candidate as Node).get_parent() == parent:
			patch = candidate as FirePatch
	if patch == null:
		patch = FirePatch.new()
		parent.add_child(patch)
	patch.start(p_source, point, affix, damage)
	return patch


func _init() -> void:
	top_level = true
	_telegraph = AttackTelegraph.new()
	add_child(_telegraph)
	_flames = MeshInstance3D.new()
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flames.mesh = _get_burn_mesh()
	_flames.position.y = 0.05
	add_child(_flames)
	visible = false


func start(p_source: Node3D, point: Vector3, affix: EliteAffix, damage: float) -> void:
	source = p_source
	radius = affix.radius
	damage_per_second = damage
	effect = affix.on_hit_effect
	global_position = Vector3(point.x, point.y, point.z)
	_windup_left = affix.windup
	_burn_left = affix.duration
	_tick_left = 0.0
	_flames.visible = false
	_flames.scale = Vector3(radius, 1.0, radius)
	_telegraph.show_circle(radius, affix.windup, FIRE_COLOR)
	add_to_group(GROUP)
	visible = true
	set_physics_process(true)


func is_burning() -> bool:
	return visible and _windup_left <= 0.0 and _burn_left > 0.0


func _physics_process(delta: float) -> void:
	if _windup_left > 0.0:
		_windup_left -= delta
		if _windup_left <= 0.0:
			_telegraph.hide_telegraph()
			_flames.visible = true
		return
	_burn_left -= delta
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left += TICK
		_burn_targets()
	if _burn_left <= 0.0:
		_finish()


func _burn_targets() -> void:
	var source_node: Node3D = source if is_instance_valid(source) else null
	for hurtbox in MeleeQuery.find_targets(
		get_tree(), global_position, Vector3.FORWARD, radius, 360.0, faction
	):
		var hit := HitInfo.create(
			source_node, hurtbox.entity, damage_per_second * TICK, Enums.DamageType.FIRE
		)
		hit.can_crit = false
		var result := Combat.apply_damage(hit)
		if effect != null and not result.evaded:
			var effects := Components.status_effects(hurtbox.entity)
			if effects != null:
				effects.apply(effect, source_node)


func _finish() -> void:
	visible = false
	remove_from_group(GROUP)
	_telegraph.hide_telegraph()
	set_physics_process(false)
	var parent := get_parent()
	if parent == null:
		return
	var pool: Array = parent.get_meta(POOL_META, [])
	if not pool.has(self):
		pool.append(self)
	parent.set_meta(POOL_META, pool)


static func _get_burn_mesh() -> Mesh:
	if _burn_mesh != null:
		return _burn_mesh
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.06
	mesh.radial_segments = 24
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.35, 0.05, 0.6)
	mat.emission_enabled = true
	mat.emission = FIRE_COLOR
	mat.emission_energy_multiplier = 2.5
	mesh.material = mat
	_burn_mesh = mesh
	return mesh
