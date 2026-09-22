class_name StatusEffectsComponent
extends Node
## Laufende Statuseffekte einer Figur: Verlangsamung, Brennen, Betäubung.
##
## - SLOW: der stärkste laufende Effekt senkt MOVE_SPEED (Prozent-Quelle &"status:slow").
## - BURN: Feuerschaden über Combat.apply_damage() in festen Takten, Resistenz zählt.
## - STUN: is_stunned() ist true; Spieler und KI fragen das ab und handeln nicht.
## Gleiche id verlängert (längere Restdauer gewinnt) und verstärkt (größere Stärke gewinnt).
## Unverwundbare Figuren (Ausweichrolle) bekommen keine neuen Effekte.

signal effect_started(effect_id: StringName, kind: StatusEffectDef.Kind)
signal effect_ended(effect_id: StringName, kind: StatusEffectDef.Kind)

const SLOW_SOURCE := &"status:slow"
## Toleranz für Rundungsfehler beim Aufsummieren kleiner Zeitschritte.
const EPSILON := 0.0001


class ActiveEffect:
	extends RefCounted
	var def: StatusEffectDef
	var time_left: float
	var magnitude: float
	var source: WeakRef
	var tick_left: float


var _active: Dictionary[StringName, ActiveEffect] = {}


func _ready() -> void:
	var health := Components.health(get_parent())
	if health != null:
		health.died.connect(func(_killer: Node3D) -> void: clear())


func _physics_process(delta: float) -> void:
	tick(delta)


## Wendet einen Effekt an. magnitude < 0 nimmt die Stärke aus def.
## Liefert false, wenn das Ziel unverwundbar oder tot ist.
func apply(def: StatusEffectDef, source: Node3D = null, magnitude: float = -1.0) -> bool:
	if def == null or def.id == &"":
		return false
	var entity := get_parent()
	var health := Components.health(entity)
	if health != null and (health.is_dead() or health.is_invulnerable()):
		return false
	var strength := def.magnitude if magnitude < 0.0 else magnitude
	var effect: ActiveEffect = _active.get(def.id)
	var is_new := effect == null
	if is_new:
		effect = ActiveEffect.new()
		effect.def = def
		effect.tick_left = def.tick_interval
		_active[def.id] = effect
	effect.time_left = maxf(effect.time_left, def.duration)
	effect.magnitude = maxf(effect.magnitude, strength)
	effect.source = weakref(source) if source != null else null
	if def.kind == StatusEffectDef.Kind.SLOW:
		_update_slow()
	if is_new:
		effect_started.emit(def.id, def.kind)
		if entity is Node3D:
			EventBus.status_effect_changed.emit(entity, def.id, true)
	return true


func remove(effect_id: StringName) -> void:
	var effect: ActiveEffect = _active.get(effect_id)
	if effect == null:
		return
	_active.erase(effect_id)
	if effect.def.kind == StatusEffectDef.Kind.SLOW:
		_update_slow()
	effect_ended.emit(effect_id, effect.def.kind)
	var entity := get_parent()
	if entity is Node3D:
		EventBus.status_effect_changed.emit(entity, effect_id, false)


func clear() -> void:
	for effect_id: StringName in _active.keys():
		remove(effect_id)


func has_effect(effect_id: StringName) -> bool:
	return _active.has(effect_id)


func has_kind(kind: StatusEffectDef.Kind) -> bool:
	for effect: ActiveEffect in _active.values():
		if effect.def.kind == kind:
			return true
	return false


func is_stunned() -> bool:
	return has_kind(StatusEffectDef.Kind.STUN)


func get_time_left(effect_id: StringName) -> float:
	var effect: ActiveEffect = _active.get(effect_id)
	return effect.time_left if effect != null else 0.0


func get_active_ids() -> Array[StringName]:
	return _active.keys()


## Stärke der aktuellen Verlangsamung (0 bis 1).
func get_slow() -> float:
	var strongest := 0.0
	for effect: ActiveEffect in _active.values():
		if effect.def.kind == StatusEffectDef.Kind.SLOW:
			strongest = maxf(strongest, effect.magnitude)
	return clampf(strongest, 0.0, 1.0)


## Lässt die Zeit um delta Sekunden laufen (auch direkt in Tests aufrufbar).
func tick(delta: float) -> void:
	if _active.is_empty():
		return
	var expired: Array[StringName] = []
	for effect_id: StringName in _active.keys():
		var effect: ActiveEffect = _active.get(effect_id)
		if effect == null:
			continue
		if effect.def.kind == StatusEffectDef.Kind.BURN:
			_tick_burn(effect, delta)
		effect.time_left -= delta
		if effect.time_left <= EPSILON:
			expired.append(effect_id)
	for effect_id in expired:
		remove(effect_id)


func _tick_burn(effect: ActiveEffect, delta: float) -> void:
	var interval := maxf(effect.def.tick_interval, 0.05)
	var remaining := minf(delta, maxf(effect.time_left, 0.0))
	effect.tick_left -= remaining
	while effect.tick_left <= EPSILON:
		effect.tick_left += interval
		var target := get_parent() as Node3D
		if target == null or not Components.is_alive(target):
			return
		var source: Node3D = effect.source.get_ref() if effect.source != null else null
		var hit := HitInfo.create(
			source, target, effect.magnitude * interval, Enums.DamageType.FIRE
		)
		hit.can_crit = false
		Combat.apply_damage(hit)


func _update_slow() -> void:
	var stats := Components.stats(get_parent())
	if stats == null:
		return
	var slow := get_slow()
	if slow <= 0.0:
		stats.remove_source(SLOW_SOURCE)
	else:
		stats.set_percent_source(SLOW_SOURCE, StatBlock.from_dict({Enums.Stat.MOVE_SPEED: -slow}))
