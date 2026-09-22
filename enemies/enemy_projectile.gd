class_name EnemyProjectile
extends HitboxComponent
## Geschoss der Gegner (Pfeil, Feuerkugel). Fliegt gerade, trifft die erste gegnerische
## Trefferfläche (über HitboxComponent) und endet an Wänden oder nach seiner Reichweite.
## Wird über spawn() erzeugt und danach wiederverwendet (kleiner Pool je Szene).

const POOL_META := &"enemy_projectile_pool"

static var _mesh_cache: Dictionary[String, Mesh] = {}

var velocity: Vector3 = Vector3.ZERO
var range_left: float = 0.0
var effect: StatusEffectDef

var _mesh: MeshInstance3D
var _shape: CollisionShape3D


## Erzeugt oder holt ein Geschoss und schießt es von origin in direction ab.
static func spawn(
	parent: Node,
	p_source: Node3D,
	origin: Vector3,
	direction: Vector3,
	attack: EnemyAttack,
	p_damage: float,
	p_effect: StatusEffectDef = null
) -> EnemyProjectile:
	var projectile := _take_from_pool(parent)
	if projectile == null:
		projectile = EnemyProjectile.new()
		parent.add_child(projectile)
	projectile.launch(p_source, origin, direction, attack, p_damage, p_effect)
	return projectile


static func _take_from_pool(parent: Node) -> EnemyProjectile:
	var pool: Array = parent.get_meta(POOL_META, [])
	while not pool.is_empty():
		var candidate: Variant = pool.pop_back()
		if is_instance_valid(candidate) and (candidate as Node).get_parent() == parent:
			return candidate as EnemyProjectile
	return null


func _init() -> void:
	faction = Enums.Faction.ENEMY
	once_per_target = true
	_shape = CollisionShape3D.new()
	_shape.shape = SphereShape3D.new()
	add_child(_shape)
	_mesh = MeshInstance3D.new()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	top_level = true
	hit_landed.connect(_on_hit_landed)


func launch(
	p_source: Node3D,
	origin: Vector3,
	direction: Vector3,
	attack: EnemyAttack,
	p_damage: float,
	p_effect: StatusEffectDef
) -> void:
	source = p_source
	damage = p_damage
	damage_type = attack.damage_type
	knockback = attack.knockback
	can_crit = true
	effect = p_effect
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	if flat == Vector3.ZERO:
		flat = Vector3.FORWARD
	velocity = flat * attack.projectile_speed
	range_left = attack.projectile_range
	(_shape.shape as SphereShape3D).radius = attack.projectile_radius
	_mesh.mesh = _projectile_mesh(attack)
	global_position = origin
	look_at(origin + flat, Vector3.UP)
	visible = true
	set_physics_process(true)
	active = true


func _physics_process(delta: float) -> void:
	if not active:
		return
	var step := velocity * delta
	var from := global_position
	var to := from + step
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD)
	var wall := get_world_3d().direct_space_state.intersect_ray(query)
	if not wall.is_empty():
		global_position = wall["position"]
		_finish()
		return
	global_position = to
	range_left -= step.length()
	if range_left <= 0.0:
		_finish()


func _on_hit_landed(target: Node3D, result: DamageResult) -> void:
	if effect != null and result != null and not result.evaded:
		var effects := Components.status_effects(target)
		if effects != null:
			effects.apply(effect, source if is_instance_valid(source) else null)
	_finish()


func _finish() -> void:
	set_deferred(&"active", false)
	visible = false
	velocity = Vector3.ZERO
	set_physics_process(false)
	var parent := get_parent()
	if parent == null:
		return
	var pool: Array = parent.get_meta(POOL_META, [])
	if not pool.has(self):
		pool.append(self)
	parent.set_meta(POOL_META, pool)


static func _projectile_mesh(attack: EnemyAttack) -> Mesh:
	var key := (
		"%s/%.2f/%d"
		% [attack.projectile_color.to_html(false), attack.projectile_radius, attack.damage_type]
	)
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = attack.projectile_color
	var mesh: PrimitiveMesh
	if attack.damage_type == Enums.DamageType.PHYSICAL:
		# Pfeil: dünner, langer Quader entlang −Z.
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 0.06, 0.8)
		mesh = box
	else:
		var sphere := SphereMesh.new()
		sphere.radius = attack.projectile_radius
		sphere.height = attack.projectile_radius * 2.0
		mesh = sphere
		mat.emission_enabled = true
		mat.emission = attack.projectile_color
		mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	_mesh_cache[key] = mesh
	return mesh
