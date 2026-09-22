class_name PlayerConfig
extends Resource
## Stellschrauben der Spielerfigur (data/player/warrior.tres). Balancing ändert die Datei.

## Grundwerte auf Stufe 1 ohne Ausrüstung.
@export var base_stats: StatBlock

@export_group("Standardangriff")
## Reichweite von der Mitte der Spielerfigur bis zum Rand des Ziels (Meter).
@export var attack_range: float = 1.8
## Öffnungswinkel des Schlags vor der Figur.
@export var attack_arc_degrees: float = 120.0
## Faktor auf Enums.Stat.DAMAGE.
@export var attack_damage_multiplier: float = 1.0
## Anteil der Angriffsdauer bis zum Treffermoment (Rest ist Ausholen zurück).
@export_range(0.05, 0.95) var attack_hit_ratio: float = 0.4
## Rückstoß des Standardangriffs in Metern.
@export var attack_knockback: float = 0.5

@export_group("Ausweichrolle")
@export var dodge_distance: float = 4.5
@export var dodge_duration: float = 0.32
## Unverwundbar vom Beginn der Rolle an so lange (Sekunden).
@export var dodge_invulnerable_time: float = 0.28
@export var dodge_cooldown: float = 2.0

@export_group("Heiltrank")
@export var potion_max_charges: int = 4
## Heilung als Anteil des maximalen Lebens.
@export_range(0.0, 1.0) var potion_heal_ratio: float = 0.35
## Mindestabstand zwischen zwei Tränken (Sekunden).
@export var potion_cooldown: float = 1.0
## So viele besiegte Gegner füllen eine Ladung auf.
@export var potion_kills_per_charge: int = 3

@export_group("Steuerung")
## Drehgeschwindigkeit der Figur (Radiant pro Sekunde).
@export var turn_speed: float = 18.0
## Beim Halten der Maustaste: so oft wird das Laufziel neu gesetzt (Sekunden).
@export var follow_retarget_interval: float = 0.1
## Mausauswahl: Gegner in diesem Abstand (Meter) zum Bodenpunkt unter der Maus zählen als getroffen.
@export var pick_radius: float = 0.6
## Ab diesem Abstand zum Ziel gilt ein Laufbefehl als erledigt (Meter).
@export var arrive_distance: float = 0.2
