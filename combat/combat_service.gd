extends Node
## Autoload „Combat“: Schadensberechnung und Trefferstopp.
##
## Vertrag: apply_damage(hit: HitInfo) -> DamageResult
##   - zieht dem Ziel Leben ab, sendet EventBus.damage_dealt
##   - sendet EventBus.entity_died, wenn das Ziel dabei stirbt
##
## Schadensformel (Werte über den Stats-Dienst):
##   1. Kritischer Treffer mit Chance CRIT_CHANCE der Quelle (nur wenn hit.can_crit):
##      Schaden × (1 + CRIT_DAMAGE der Quelle)
##   2. Physisch: × (1 - Rüstung / (Rüstung + armor_constant)), höchstens max_armor_reduction
##      Feuer, Kälte, Gift: × (1 - Resistenz), Resistenz zwischen min_resist und max_resist
##   3. Unverwundbares Ziel (Ausweichrolle): kein Schaden, result.evaded, kein Signal
##   4. Leben bei Treffer (LIFE_ON_HIT) heilt die Quelle, Rückstoß (hit.knockback) schiebt das Ziel
## Die Stellschrauben stehen in data/combat/combat_config.tres.

const CONFIG_PATH := "res://data/combat/combat_config.tres"

var config: CombatConfig
## Trefferstopp an oder aus (zum Beispiel für Tests).
var hit_stop_enabled: bool = true

var _rng: RandomNumberGenerator
var _hit_stop_until_msec: int = 0


func _ready() -> void:
	if ResourceLoader.exists(CONFIG_PATH):
		config = load(CONFIG_PATH) as CombatConfig
	if config == null:
		config = CombatConfig.new()
	_rng = Rng.stream(&"combat")
	process_mode = Node.PROCESS_MODE_ALWAYS


## Eigener Zufallsstrom für kritische Treffer (Tests, Wiederholungen).
func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


func apply_damage(hit: HitInfo) -> DamageResult:
	var result := DamageResult.new()
	if hit == null or not is_instance_valid(hit.target):
		return result
	var target := hit.target
	var source: Node3D = hit.source if is_instance_valid(hit.source) else null
	var health := Components.health(target)
	if health != null and health.is_dead():
		return result
	if health != null and health.is_invulnerable():
		result.evaded = true
		return result

	var amount := maxf(hit.base, 0.0)
	if hit.can_crit and source != null and amount > 0.0:
		var chance := clampf(Stats.get_stat(source, Enums.Stat.CRIT_CHANCE), 0.0, 1.0)
		if chance > 0.0 and _rng.randf() < chance:
			result.crit = true
			amount *= 1.0 + maxf(Stats.get_stat(source, Enums.Stat.CRIT_DAMAGE), 0.0)
	amount *= mitigation(target, hit.type)
	result.amount = amount

	if health != null:
		result.killed = health.take_damage(amount, source)
	elif target.has_method("take_damage"):
		# Ersatz-Konvention aus AP0 für Ziele ohne HealthComponent.
		result.killed = target.take_damage(amount)

	if source != null and amount > 0.0:
		_apply_life_on_hit(source)
		if hit.knockback > 0.0:
			var knockback := Components.knockback(target)
			if knockback != null:
				knockback.apply(target.global_position - source.global_position, hit.knockback)

	EventBus.damage_dealt.emit(hit, result)
	if result.killed:
		EventBus.entity_died.emit(target, source)
	return result


## Anteil des Schadens, der nach Rüstung oder Resistenz beim Ziel ankommt (0 bis 2).
func mitigation(target: Node, type: Enums.DamageType) -> float:
	if type == Enums.DamageType.PHYSICAL:
		return 1.0 - armor_reduction(Stats.get_stat(target, Enums.Stat.ARMOR))
	var resist := Stats.get_stat(target, resist_stat(type))
	return 1.0 - clampf(resist, config.min_resist, config.max_resist)


## Schadensminderung durch Rüstung (0 bis max_armor_reduction).
func armor_reduction(armor: float) -> float:
	if armor <= 0.0:
		return 0.0
	return minf(armor / (armor + config.armor_constant), config.max_armor_reduction)


static func resist_stat(type: Enums.DamageType) -> Enums.Stat:
	match type:
		Enums.DamageType.FIRE:
			return Enums.Stat.FIRE_RESIST
		Enums.DamageType.COLD:
			return Enums.Stat.COLD_RESIST
		Enums.DamageType.POISON:
			return Enums.Stat.POISON_RESIST
	return Enums.Stat.ARMOR


static func are_hostile(a: Enums.Faction, b: Enums.Faction) -> bool:
	return a != b


## Friert das Spiel kurz fast ein (Wucht bei Treffern). duration in Echtzeit-Sekunden.
## Überlappende Aufrufe verlängern bis zum spätesten Ende. Setzt Engine.time_scale danach auf 1.
## Das Ende wird in _process() über die Echtzeit geprüft, nicht über einen Timer, weil
## Timer mit ignore_time_scale bei stark gesenkter Zeitskala zu früh auslösen.
func hit_stop(duration: float) -> void:
	if not hit_stop_enabled or duration <= 0.0 or not is_inside_tree():
		return
	var until := Time.get_ticks_msec() + int(duration * 1000.0)
	if until <= _hit_stop_until_msec:
		return
	_hit_stop_until_msec = until
	Engine.time_scale = config.hit_stop_time_scale


## Trefferstopp für einen gelandeten Schlag: kurz bei normalen, länger bei kritischen
## Treffern und Todesstößen (dann wackelt auch die Kamera).
func hit_stop_for(results: Array[DamageResult]) -> void:
	var landed := false
	var heavy := false
	for result in results:
		if result != null and result.amount > 0.0:
			landed = true
			heavy = heavy or result.crit or result.killed
	if not landed:
		return
	hit_stop(config.hit_stop_heavy if heavy else config.hit_stop_normal)
	if heavy:
		var rig := CameraRig.get_active()
		if rig != null:
			rig.shake(config.heavy_shake_strength, 0.2)


func is_hit_stop_active() -> bool:
	return Time.get_ticks_msec() < _hit_stop_until_msec


func _process(_delta: float) -> void:
	if _hit_stop_until_msec > 0 and Time.get_ticks_msec() >= _hit_stop_until_msec:
		_hit_stop_until_msec = 0
		Engine.time_scale = 1.0


func _apply_life_on_hit(source: Node3D) -> void:
	var life_on_hit := Stats.get_stat(source, Enums.Stat.LIFE_ON_HIT)
	if life_on_hit <= 0.0:
		return
	var source_health := Components.health(source)
	if source_health != null:
		source_health.heal(life_on_hit)
