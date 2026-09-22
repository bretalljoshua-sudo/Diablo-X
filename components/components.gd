class_name Components
## Findet Komponenten an einer Figur. Eine Komponente ist entweder die Figur selbst
## oder ein direktes Kind der Figur.


static func find(entity: Node, type: Script) -> Node:
	if entity == null or not is_instance_valid(entity):
		return null
	if is_instance_of(entity, type):
		return entity
	for child in entity.get_children():
		if is_instance_of(child, type):
			return child
	return null


static func stats(entity: Node) -> StatsComponent:
	return find(entity, StatsComponent) as StatsComponent


static func health(entity: Node) -> HealthComponent:
	return find(entity, HealthComponent) as HealthComponent


static func hurtbox(entity: Node) -> HurtboxComponent:
	return find(entity, HurtboxComponent) as HurtboxComponent


static func status_effects(entity: Node) -> StatusEffectsComponent:
	return find(entity, StatusEffectsComponent) as StatusEffectsComponent


static func knockback(entity: Node) -> KnockbackComponent:
	return find(entity, KnockbackComponent) as KnockbackComponent


## true, wenn die Figur lebt (Figuren ohne HealthComponent gelten als lebendig).
static func is_alive(entity: Node) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	var h := health(entity)
	return h == null or not h.is_dead()


## true, wenn die Figur gerade betäubt ist.
static func is_stunned(entity: Node) -> bool:
	var effects := status_effects(entity)
	return effects != null and effects.is_stunned()
