class_name StatsComponent
extends Node
## Werte einer Figur: Grundwerte plus Quellen (Ausrüstung, Stufe, Effekte).
##
## Rechnung je Stat:  (Grundwert + Summe der festen Quellen) × (1 + Summe der Prozent-Quellen)
## Prozent-Quellen sind Anteile: -0.3 bedeutet 30 % weniger. Das Ergebnis ist nie kleiner als
## 0, wenn Prozent-Quellen zusammen unter -100 % liegen.
##
## Andere Pakete setzen Quellen über den Stats-Dienst, zum Beispiel
## Stats.set_flat_source(player, &"level", block).

signal stats_changed

## Grundwerte. Fehlende Stats nehmen den Standardwert aus StatDefaults.
@export var base_stats: StatBlock:
	set(value):
		base_stats = value
		_invalidate()

var _flat: Dictionary[StringName, StatBlock] = {}
var _percent: Dictionary[StringName, StatBlock] = {}
var _cache: Dictionary[Enums.Stat, float] = {}


func get_value(stat: Enums.Stat) -> float:
	if _cache.has(stat):
		return _cache[stat]
	var value := StatDefaults.get_default(stat)
	if base_stats != null:
		value = base_stats.get_value(stat, value)
	for block: StatBlock in _flat.values():
		value += block.get_value(stat)
	var percent := 0.0
	for block: StatBlock in _percent.values():
		percent += block.get_value(stat)
	value *= maxf(1.0 + percent, 0.0)
	_cache[stat] = value
	return value


## Alle Werte als neuer StatBlock (für Tooltips und Charakterfenster).
func snapshot() -> StatBlock:
	var block := StatBlock.new()
	for stat: int in Enums.Stat.values():
		block.set_value(stat as Enums.Stat, get_value(stat as Enums.Stat))
	return block


## Setzt eine feste Quelle, zum Beispiel &"equipment:weapon". null entfernt sie.
func set_flat_source(key: StringName, block: StatBlock) -> void:
	_set_source(_flat, key, block)


## Setzt eine Prozent-Quelle, zum Beispiel &"status:slow" mit MOVE_SPEED = -0.3. null entfernt sie.
func set_percent_source(key: StringName, block: StatBlock) -> void:
	_set_source(_percent, key, block)


func remove_source(key: StringName) -> void:
	var removed := _flat.erase(key)
	removed = _percent.erase(key) or removed
	if removed:
		_invalidate()


func has_source(key: StringName) -> bool:
	return _flat.has(key) or _percent.has(key)


func get_source(key: StringName) -> StatBlock:
	if _flat.has(key):
		return _flat[key]
	return _percent.get(key)


func _set_source(
	target: Dictionary[StringName, StatBlock], key: StringName, block: StatBlock
) -> void:
	if block == null:
		if target.erase(key):
			_invalidate()
		return
	# Kopie, damit spätere Änderungen am übergebenen Block nicht unbemerkt durchschlagen.
	target[key] = block.plus(null)
	_invalidate()


func _invalidate() -> void:
	_cache.clear()
	stats_changed.emit()
