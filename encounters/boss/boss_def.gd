class_name BossDef
extends Resource
## Ein Boss als Daten (data/encounters/<id>.tres): Gegnertyp aus AP3 für Phase 1, dazu was sich in
## Phase 2 ändert. Die Wirkung baut BossController.
##
## Phase 2 beginnt, sobald das Leben unter phase_two_threshold fällt. Dann brüllt der Boss kurz
## (unverwundbar), bekommt die Angriffe aus phase_two_attacks dazu (etwa Beschwören) und legt
## in festen Abständen Feuerflächen unter und um den Spieler.

## Name im Spiel, erscheint im Bossbalken (AP7).
@export var display_name: String = "Der Gruftwächter"
## Gegnertyp für Phase 1 (Werte, Modell, Angriffe).
@export var enemy_type: EnemyType
## Diese Angriffe kommen in Phase 2 vorne dazu (werden also bevorzugt, wenn bereit).
@export var phase_two_attacks: Array[EnemyAttack] = []
## Anteil des Lebens, ab dem Phase 2 beginnt.
@export_range(0.05, 0.95) var phase_two_threshold: float = 0.5
## Angriffe laufen in Phase 2 um diesen Faktor schneller.
@export var phase_two_attack_speed: float = 1.15
## Dauer des Brüllens beim Phasenwechsel (unverwundbar, greift nicht an).
@export var phase_change_time: float = 1.6

@export_group("Feuerflächen (Phase 2)")
## Werte der Feuerfläche (EliteAffix vom Typ BURNING: radius, windup, duration, on_hit_effect).
@export var fire_affix: EliteAffix
## Abstand zwischen zwei Feuerwellen in Sekunden.
@export var fire_interval: float = 6.0
## Flächen je Welle: eine unter dem Spieler, die übrigen zufällig um ihn herum.
@export var fire_count: int = 3
## Abstand der zusätzlichen Flächen vom Spieler.
@export var fire_spread: float = 4.5
## Feuerschaden pro Sekunde als Anteil von DAMAGE des Bosses.
@export var fire_damage_factor: float = 0.45

@export_group("Kampf")
## Betäubungen enden am Boss nach höchstens so vielen Sekunden.
@export var max_stun_time: float = 0.6
## Abstand zur Bossraum-Mitte, ab dem der Kampf beginnt (zusätzlich zum Betreten des Raums).
@export var engage_radius: float = 13.0
## Stufe des Bosses über der Stufe der Ebene davor.
@export var level_bonus: int = 1
## Beutetabelle der Belohnungstruhe (AP4) und wie oft gewürfelt wird.
@export var chest_table: LootTable
@export var chest_rolls: int = 2
