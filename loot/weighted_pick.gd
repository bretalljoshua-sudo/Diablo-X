class_name WeightedPick
extends RefCounted
## Gewichtete Zufallsauswahl, reproduzierbar über den übergebenen Zufallsstrom.


## Index eines Eintrags nach Gewicht, -1 wenn alle Gewichte 0 sind.
static func pick_index(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for weight: float in weights:
		total += maxf(weight, 0.0)
	if total <= 0.0:
		return -1
	var roll := rng.randf() * total
	for i in weights.size():
		var weight := maxf(float(weights[i]), 0.0)
		if roll < weight:
			return i
		roll -= weight
	# Rundungsfehler: letzter Eintrag mit Gewicht.
	for i in range(weights.size() - 1, -1, -1):
		if float(weights[i]) > 0.0:
			return i
	return -1
