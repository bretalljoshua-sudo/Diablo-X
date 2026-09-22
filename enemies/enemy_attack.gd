class_name EnemyAttack
extends Resource
## Ein Angriff eines Gegnertyps als Daten (Teil von EnemyType.attacks).
##
## Ablauf: Vorwarnung (windup, sichtbar am Boden) → Treffer → Erholung (recovery, der Gegner
## steht still und ist offen) → Abklingzeit (cooldown, zählt ab Beginn des Angriffs).
## Der Treffer prüft genau die Fläche, die die Vorwarnung gezeigt hat: Wer sie rechtzeitig
## verlässt oder durch sie hindurchrollt, wird nicht getroffen.

enum Kind {
	## Schlag im Kreisbogen vor dem Gegner (Vorwarnung: Kegel).
	MELEE,
	## Wuchtiger Schlag auf eine Kreisfläche vor dem Gegner (Vorwarnung: Kreis).
	SLAM,
	## Geschoss entlang einer Linie (Vorwarnung: Linie).
	PROJECTILE,
	## Ruft Diener herbei (Vorwarnung: Kreise an den Erscheinungsorten).
	SUMMON,
}

@export var id: StringName = &""
@export var kind: Kind = Kind.MELEE
## Nur einsetzen, wenn der Abstand zum Rand des Ziels zwischen min_range und max_range liegt.
@export var min_range: float = 0.0
@export var max_range: float = 1.6
## Vorwarnzeit in Sekunden.
@export var windup: float = 0.6
## Erholung nach dem Treffer in Sekunden.
@export var recovery: float = 0.5
## Abklingzeit in Sekunden ab Beginn des Angriffs.
@export var cooldown: float = 1.5
## Schaden = DAMAGE des Gegners × damage_factor.
@export var damage_factor: float = 1.0
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
@export var knockback: float = 0.0
## Effekt bei Treffer (Verlangsamung, Brennen, Betäubung), darf leer sein.
@export var effect: StatusEffectDef

@export_group("Fläche")
## MELEE: Öffnungswinkel des Kegels in Grad.
@export var arc_degrees: float = 100.0
## MELEE: Reichweite des Kegels. SLAM und SUMMON: Radius der Kreisfläche.
@export var radius: float = 1.6
## SLAM: Abstand des Kreismittelpunkts vor dem Gegner.
@export var forward_offset: float = 0.0

@export_group("Geschoss")
@export var projectile_speed: float = 16.0
@export var projectile_range: float = 14.0
@export var projectile_radius: float = 0.35
@export var projectile_color: Color = Color(0.9, 0.85, 0.7)
## Bis so viele Sekunden vor dem Abschuss folgt die Zielrichtung dem Ziel, danach steht sie fest.
@export var aim_lock_before: float = 0.3

@export_group("Beschwören")
@export var summon_type: EnemyDef
@export var summon_count: int = 2
## Höchstens so viele eigene Diener gleichzeitig.
@export var summon_max_alive: int = 4
## Abstand der Erscheinungsorte vom Beschwörer.
@export var summon_distance: float = 2.5

@export_group("Animation")
## Aktion für play_action() am Modell (AP8: attack_1 … attack_4, cast). Das Tempo wird so
## gewählt, dass der Treffer- oder Abschusszeitpunkt der Animation am Ende der Vorwarnung liegt.
@export var animation: StringName = &"attack_1"


func is_in_range(edge_distance: float) -> bool:
	return edge_distance >= min_range and edge_distance <= max_range
