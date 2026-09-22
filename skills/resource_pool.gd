class_name ResourcePool
extends RefCounted
## Klassenressource des Spielers (Krieger: Wut). Basis-Skills bauen sie auf, Kern-Skills
## verbrauchen sie. Das Maximum kommt aus Enums.Stat.RESOURCE_MAX.

signal changed(current: float, maximum: float)

var current: float = 0.0
var maximum: float = 100.0


func set_maximum(value: float) -> void:
	value = maxf(value, 1.0)
	if is_equal_approx(value, maximum):
		return
	maximum = value
	current = minf(current, maximum)
	changed.emit(current, maximum)


func can_afford(amount: float) -> bool:
	return current + 0.0001 >= amount


## Zieht amount ab, wenn genug da ist.
func spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if not can_afford(amount):
		return false
	_set_current(current - amount)
	return true


## Baut auf und liefert die tatsächlich gewonnene Menge.
func gain(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var before := current
	_set_current(current + amount)
	return current - before


func fill() -> void:
	_set_current(maximum)


func clear() -> void:
	_set_current(0.0)


func get_ratio() -> float:
	return current / maximum if maximum > 0.0 else 0.0


func _set_current(value: float) -> void:
	value = clampf(value, 0.0, maximum)
	if is_equal_approx(value, current):
		return
	current = value
	changed.emit(current, maximum)
