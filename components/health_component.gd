class_name HealthComponent
extends Node
## Leben einer Figur. Das Maximum kommt aus Enums.Stat.MAX_LIFE der StatsComponent
## derselben Figur (sonst fallback_max_life). Schaden läuft über Combat.apply_damage(),
## nicht direkt über take_damage(), damit Rüstung, Signale und Tod einheitlich sind.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node3D)
signal healed(amount: float)
signal died(killer: Node3D)
signal revived

## Maximum, wenn die Figur keine StatsComponent hat.
@export var fallback_max_life: float = 100.0

var current: float = 0.0
var maximum: float = 0.0

var _dead: bool = false
var _invulnerable_reasons: Dictionary[StringName, bool] = {}
var _stats: StatsComponent


func _ready() -> void:
	_stats = Components.stats(get_parent())
	if _stats != null:
		_stats.stats_changed.connect(_on_stats_changed)
	maximum = _read_maximum()
	current = maximum
	health_changed.emit(current, maximum)


func is_dead() -> bool:
	return _dead


func get_ratio() -> float:
	return current / maximum if maximum > 0.0 else 0.0


func is_invulnerable() -> bool:
	return not _invulnerable_reasons.is_empty()


## Schaltet Unverwundbarkeit aus einem Grund an oder aus (zum Beispiel &"dodge").
## Mehrere Gründe gleichzeitig sind möglich; unverwundbar, solange einer aktiv ist.
func set_invulnerable(reason: StringName, enabled: bool) -> void:
	if enabled:
		_invulnerable_reasons[reason] = true
	else:
		_invulnerable_reasons.erase(reason)


## Zieht Leben ab. Liefert true, wenn die Figur durch diesen Schaden stirbt.
func take_damage(amount: float, source: Node3D = null) -> bool:
	if _dead or amount <= 0.0:
		return false
	current = maxf(current - amount, 0.0)
	damaged.emit(amount, source)
	health_changed.emit(current, maximum)
	if current <= 0.0:
		_dead = true
		died.emit(source)
		return true
	return false


## Heilt und liefert die tatsächlich geheilte Menge.
func heal(amount: float) -> float:
	if _dead or amount <= 0.0:
		return 0.0
	var before := current
	current = minf(current + amount, maximum)
	var delta := current - before
	if delta > 0.0:
		healed.emit(delta)
		health_changed.emit(current, maximum)
	return delta


## Erweckt die Figur mit einem Anteil des Maximums wieder.
func revive(ratio: float = 1.0) -> void:
	maximum = _read_maximum()
	current = maxf(maximum * clampf(ratio, 0.0, 1.0), 1.0)
	_dead = false
	_invulnerable_reasons.clear()
	revived.emit()
	health_changed.emit(current, maximum)


## Setzt das Leben auf das Maximum (ohne Tod oder Wiederbelebung zu melden).
func reset_to_full() -> void:
	maximum = _read_maximum()
	current = maximum
	health_changed.emit(current, maximum)


func _read_maximum() -> float:
	if _stats != null:
		return maxf(_stats.get_value(Enums.Stat.MAX_LIFE), 1.0)
	return maxf(fallback_max_life, 1.0)


func _on_stats_changed() -> void:
	var new_max := _read_maximum()
	if is_equal_approx(new_max, maximum):
		return
	# Anteil bleibt gleich, wenn sich das Maximum ändert (zum Beispiel durch Ausrüstung).
	var ratio := get_ratio()
	maximum = new_max
	if not _dead:
		current = clampf(maximum * ratio, 1.0, maximum)
	health_changed.emit(current, maximum)
