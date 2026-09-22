class_name DamageResult
extends RefCounted
## Ergebnis von Combat.apply_damage().

## Tatsächlich abgezogenes Leben nach allen Berechnungen.
var amount: float = 0.0
var crit: bool = false
var killed: bool = false
