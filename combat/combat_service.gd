extends Node
## Autoload „Combat“. ERSATZVERSION aus AP0: Schaden = Grundschaden, ohne Rüstung,
## Resistenzen und kritische Treffer. AP2 ersetzt den Inhalt, die Signatur bleibt.
##
## Vertrag: apply_damage(hit: HitInfo) -> DamageResult
##   - zieht dem Ziel Leben ab, sendet EventBus.damage_dealt
##   - sendet EventBus.entity_died, wenn das Ziel dabei stirbt


func apply_damage(hit: HitInfo) -> DamageResult:
	var result := DamageResult.new()
	if hit == null or not is_instance_valid(hit.target):
		return result
	result.amount = maxf(hit.base, 0.0)
	# Ersatz-Konvention bis AP2: Ziele mit take_damage(amount) -> bool (true = gestorben).
	if hit.target.has_method("take_damage"):
		result.killed = hit.target.take_damage(result.amount)
	EventBus.damage_dealt.emit(hit, result)
	if result.killed:
		EventBus.entity_died.emit(hit.target, hit.source)
	return result
