class_name DamageResult
extends RefCounted
## Ergebnis von Combat.apply_damage().

## Tatsächlich abgezogenes Leben nach allen Berechnungen.
var amount: float = 0.0
var crit: bool = false
var killed: bool = false
## true, wenn das Ziel unverwundbar war (zum Beispiel Ausweichrolle). Dann gibt es keinen
## Schaden und kein EventBus.damage_dealt.
var evaded: bool = false
