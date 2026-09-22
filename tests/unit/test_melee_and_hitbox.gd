extends GutTest
## MeleeQuery (Nahkampf-Zielsuche) und HitboxComponent (AP2).

const Entity := preload("res://tests/unit/ap2_entity.gd")


func _make_target(pos: Vector3, faction := Enums.Faction.ENEMY) -> Node3D:
	var entity := Entity.make({Enums.Stat.MAX_LIFE: 100.0})
	var hurtbox := HurtboxComponent.new()
	hurtbox.name = "Hurtbox"
	hurtbox.faction = faction
	hurtbox.radius = 0.5
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.5
	shape.shape = cylinder
	hurtbox.add_child(shape)
	entity.add_child(hurtbox)
	entity.position = pos
	add_child_autofree(entity)
	return entity


func _entities(hurtboxes: Array[HurtboxComponent]) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for hurtbox in hurtboxes:
		result.append(hurtbox.entity)
	return result


func test_finds_targets_in_front_within_reach() -> void:
	var front := _make_target(Vector3(0, 0, -1.5))
	var behind := _make_target(Vector3(0, 0, 1.5))
	var far := _make_target(Vector3(0, 0, -5))
	var side := _make_target(Vector3(1.4, 0, -0.9))
	var found := _entities(
		MeleeQuery.find_targets(
			get_tree(), Vector3.ZERO, Vector3.FORWARD, 1.8, 120.0, Enums.Faction.PLAYER
		)
	)
	assert_has(found, front)
	assert_has(found, side, "57° liegt im 120°-Bogen")
	assert_does_not_have(found, behind)
	assert_does_not_have(found, far)
	assert_eq(found[0], front, "nach Abstand sortiert")


func test_ignores_same_faction_and_dead() -> void:
	var ally := _make_target(Vector3(0, 0, -1), Enums.Faction.PLAYER)
	var dead := _make_target(Vector3(0.5, 0, -1))
	Components.health(dead).take_damage(1000.0)
	var found := _entities(
		MeleeQuery.find_targets(
			get_tree(), Vector3.ZERO, Vector3.FORWARD, 2.0, 360.0, Enums.Faction.PLAYER
		)
	)
	assert_does_not_have(found, ally)
	assert_does_not_have(found, dead)


func test_nearest_hostile() -> void:
	var a := _make_target(Vector3(3, 0, 0))
	_make_target(Vector3(5, 0, 0))
	var hurtbox := MeleeQuery.nearest_hostile(
		get_tree(), Vector3(3.6, 0, 0), 0.5, Enums.Faction.PLAYER
	)
	assert_not_null(hurtbox)
	assert_eq(hurtbox.entity, a)
	assert_null(
		MeleeQuery.nearest_hostile(get_tree(), Vector3(10, 0, 0), 0.5, Enums.Faction.PLAYER)
	)


func test_hitbox_hits_overlapping_hurtbox_once_per_activation() -> void:
	var target := _make_target(Vector3(0, 0, 0))
	var hitbox := HitboxComponent.new()
	hitbox.faction = Enums.Faction.PLAYER
	hitbox.damage = 10.0
	hitbox.can_crit = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	hitbox.add_child(shape)
	var attacker := Node3D.new()
	attacker.add_child(hitbox)
	attacker.position = Vector3(0.5, 0, 0)
	add_child_autofree(attacker)
	await wait_physics_frames(3)
	watch_signals(hitbox)
	hitbox.active = true
	await wait_physics_frames(3)
	var health := Components.health(target)
	assert_eq(health.current, 90.0)
	assert_signal_emit_count(hitbox, "hit_landed", 1)
	hitbox.active = false
	hitbox.active = true
	assert_eq(health.current, 80.0, "neue Aktivierung trifft erneut")
