class_name MeleeQuery
## Sucht Ziele für Nahkampfschläge ohne Physik-Abfrage: alle gegnerischen, lebenden
## HurtboxComponents in einem Kreisbogen vor dem Angreifer. Gemessen wird waagerecht
## vom Angreifer bis zum Rand der Zielfigur (Abstand minus radius der Hurtbox).


## Ziele im Bogen, nach Abstand sortiert. arc_degrees 360 = rundherum.
static func find_targets(
	tree: SceneTree,
	origin: Vector3,
	forward: Vector3,
	reach: float,
	arc_degrees: float,
	attacker_faction: Enums.Faction
) -> Array[HurtboxComponent]:
	var result: Array[HurtboxComponent] = []
	var flat_forward := Vector3(forward.x, 0.0, forward.z)
	if flat_forward.length_squared() < 0.0001:
		flat_forward = Vector3.FORWARD
	flat_forward = flat_forward.normalized()
	var half_arc := deg_to_rad(arc_degrees) * 0.5
	for node in tree.get_nodes_in_group(HurtboxComponent.GROUP):
		var hurtbox := node as HurtboxComponent
		if not _is_valid_target(hurtbox, attacker_faction):
			continue
		var to_target := hurtbox.global_position - origin
		to_target.y = 0.0
		var distance := to_target.length()
		if distance - hurtbox.radius > reach:
			continue
		# Sehr nahe Ziele zählen immer, sonst entscheidet der Winkel.
		if arc_degrees < 360.0 and distance > hurtbox.radius + 0.25:
			if flat_forward.angle_to(to_target / distance) > half_arc:
				continue
		result.append(hurtbox)
	result.sort_custom(
		func(a: HurtboxComponent, b: HurtboxComponent) -> bool:
			return (
				origin.distance_squared_to(a.global_position)
				< origin.distance_squared_to(b.global_position)
			)
	)
	return result


## Nächste gegnerische, lebende Hurtbox, deren Rand höchstens max_distance von point entfernt ist.
static func nearest_hostile(
	tree: SceneTree, point: Vector3, max_distance: float, attacker_faction: Enums.Faction
) -> HurtboxComponent:
	var best: HurtboxComponent = null
	var best_distance := INF
	for node in tree.get_nodes_in_group(HurtboxComponent.GROUP):
		var hurtbox := node as HurtboxComponent
		if not _is_valid_target(hurtbox, attacker_faction):
			continue
		var offset := hurtbox.global_position - point
		offset.y = 0.0
		var distance := offset.length() - hurtbox.radius
		if distance <= max_distance and distance < best_distance:
			best = hurtbox
			best_distance = distance
	return best


## Waagerechter Abstand von point bis zum Rand der Zielfigur (negativ = innerhalb).
static func edge_distance(point: Vector3, target: Node3D) -> float:
	var offset := target.global_position - point
	offset.y = 0.0
	var hurtbox := Components.hurtbox(target)
	return offset.length() - (hurtbox.radius if hurtbox != null else 0.0)


static func _is_valid_target(hurtbox: HurtboxComponent, attacker_faction: Enums.Faction) -> bool:
	return (
		hurtbox != null
		and hurtbox.is_inside_tree()
		and hurtbox.collision_layer != 0
		and is_instance_valid(hurtbox.entity)
		and hurtbox.is_hostile_to(attacker_faction)
		and hurtbox.is_alive()
	)
