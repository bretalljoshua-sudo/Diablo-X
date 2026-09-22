class_name EnemyType
extends EnemyDef
## Gegnertyp mit allem, was die KI aus AP3 braucht (data/enemies/*.tres).
## Erweitert den Vertrag EnemyDef, bleibt also überall als EnemyDef nutzbar.
##
## behavior (aus EnemyDef) steuert das Laufen:
##   &"melee"     läuft zum Ziel und schlägt zu (Skelett, Ghul)
##   &"ranged"    hält Abstand zwischen keep_distance_min und keep_distance_max (Bogenschütze)
##   &"summoner"  wie ranged, weicht aber zurück, wenn das Ziel näher als flee_distance kommt

## Modell von AP8, zum Beispiel "res://assets/characters/skeleton.tscn". Fehlt die Datei,
## erscheint eine Kapsel in placeholder_color.
@export_file("*.tscn") var model_path: String = ""
@export var placeholder_color: Color = Color(0.8, 0.8, 0.75)
## Treffer-Effekt aus AP1 (VfxLibrary), zum Beispiel &"bone_chips" oder &"blood".
@export var hit_vfx: StringName = &"blood"
## Körpermaße für Kollision und Trefferfläche.
@export var body_radius: float = 0.4
@export var body_height: float = 1.8
@export var model_scale: float = 1.0
## 0 = voller Rückstoß, 1 = unbeweglich.
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0

@export_group("Wahrnehmung")
## Ab diesem Abstand bemerkt der Gegner das Ziel (mit Sichtlinie).
@export var aggro_range: float = 11.0
## Reaktionszeit zwischen Bemerken und Verfolgen.
@export var notice_time: float = 0.45
## Gibt die Verfolgung auf, wenn das Ziel weiter weg ist.
@export var lose_range: float = 30.0

@export_group("Abstand")
@export var keep_distance_min: float = 0.0
@export var keep_distance_max: float = 0.0
@export var flee_distance: float = 0.0

@export_group("Angriffe")
## In Reihenfolge der Vorliebe: der erste Angriff, der bereit ist und passt, wird genommen.
@export var attacks: Array[EnemyAttack] = []


## Werte auf einer Stufe: base_stats + stats_per_level × (Stufe − 1).
func stats_for_level(level: int) -> StatBlock:
	var block := StatBlock.new()
	block.add(base_stats)
	if stats_per_level != null and level > 1:
		for stat: Enums.Stat in stats_per_level.values:
			block.set_value(
				stat, block.get_value(stat) + stats_per_level.values[stat] * (level - 1)
			)
	return block


## Erfahrung für einen besiegten Gegner dieser Stufe (ohne Elite-Bonus).
func experience_for_level(level: int) -> int:
	return int(roundf(experience * (1.0 + 0.2 * (maxi(level, 1) - 1))))


func is_ranged() -> bool:
	return behavior == &"ranged" or behavior == &"summoner"
