class_name EliteAffix
extends Resource
## Elite-Eigenschaft als Daten (data/enemies/elite/*.tres). Die Wirkung baut EliteAffixes.

enum Kind { FAST, BURNING, SHIELDING, TELEPORTING, VAMPIRIC }

@export var id: StringName = &""
## Name im Spiel, zum Beispiel „Schnell“.
@export var display_name: String = ""
@export var kind: Kind = Kind.FAST
## Farbe des Leuchtrings und der Vorwarnungen dieser Eigenschaft.
@export var color: Color = Color(1, 0.8, 0.2)

@export_group("Werte")
## FAST: Anteil mehr Laufgeschwindigkeit (0.4 = +40 %).
@export var move_speed_bonus: float = 0.0
## FAST: Angriffe laufen um diesen Faktor schneller (1.3 = Vorwarnung, Erholung und
## Abklingzeit dauern nur 1/1.3 so lange).
@export var attack_speed_multiplier: float = 1.0
## BURNING, SHIELDING, TELEPORTING: Abstand zwischen zwei Auslösungen in Sekunden.
@export var interval: float = 6.0
## BURNING: Brenndauer der Feuerfläche. SHIELDING: Dauer des Schilds.
@export var duration: float = 3.0
## BURNING: Radius der Feuerfläche. SHIELDING: Radius, in dem Gruppenmitglieder den Schild
## mitbekommen. TELEPORTING: Abstand zum Ziel nach dem Sprung.
@export var radius: float = 2.0
## BURNING: Vorwarnzeit der Feuerfläche. TELEPORTING: Vorwarnzeit am Zielort.
@export var windup: float = 1.0
## BURNING: Feuerschaden pro Sekunde auf der Fläche als Anteil von DAMAGE.
@export var damage_factor: float = 0.0
## BURNING: Effekt der Treffer des Elite-Gegners (Brennen).
@export var on_hit_effect: StatusEffectDef
## VAMPIRIC: Anteil des verursachten Schadens, der den Gegner heilt (0.5 = 50 %).
@export var life_steal: float = 0.0
## TELEPORTING: springt nur, wenn das Ziel mindestens so weit entfernt ist.
@export var min_distance: float = 4.0
