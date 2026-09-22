class_name StatusEffectDef
extends Resource
## Beschreibung eines Statuseffekts als Daten (data/status_effects/*.tres).
## Angewendet über StatusEffectsComponent.apply() an der Zielfigur.

enum Kind { SLOW, BURN, STUN }

## Eindeutiger Name. Gleiche id verlängert den laufenden Effekt statt ihn zu stapeln.
@export var id: StringName = &""
@export var kind: Kind = Kind.SLOW
## Dauer in Sekunden.
@export var duration: float = 2.0
## SLOW: Anteil der Verlangsamung (0.3 = 30 % langsamer).
## BURN: Feuerschaden pro Sekunde. STUN: ohne Bedeutung.
@export var magnitude: float = 0.3
## BURN: Abstand zwischen zwei Schadenstakten in Sekunden.
@export var tick_interval: float = 0.5


static func create(
	p_id: StringName, p_kind: Kind, p_duration: float, p_magnitude: float = 0.0
) -> StatusEffectDef:
	var def := StatusEffectDef.new()
	def.id = p_id
	def.kind = p_kind
	def.duration = p_duration
	def.magnitude = p_magnitude
	return def
