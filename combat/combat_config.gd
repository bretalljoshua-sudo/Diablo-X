class_name CombatConfig
extends Resource
## Stellschrauben der Schadensformel und des Trefferstopps (data/combat/combat_config.tres).
## Balancing (AP9) ändert diese Datei, nicht den Code.

@export_group("Rüstung und Resistenzen")
## Rüstungsminderung = Rüstung / (Rüstung + armor_constant). Bei 200: 200 Rüstung = 50 %.
@export var armor_constant: float = 200.0
@export_range(0.0, 1.0) var max_armor_reduction: float = 0.85
## Höchste Resistenz gegen Feuer, Kälte und Gift (0.75 = 75 %).
@export_range(0.0, 1.0) var max_resist: float = 0.75
## Niedrigste Resistenz (negativ = Anfälligkeit, -0.5 = 50 % mehr Schaden).
@export_range(-1.0, 0.0) var min_resist: float = -1.0

@export_group("Trefferstopp")
## Spielgeschwindigkeit während des Trefferstopps (0.05 = fast eingefroren).
@export var hit_stop_time_scale: float = 0.05
## Dauer bei normalem Treffer in Sekunden (Echtzeit).
@export var hit_stop_normal: float = 0.045
## Dauer bei kritischem Treffer oder Todesstoß.
@export var hit_stop_heavy: float = 0.085
## Kamerawackeln bei kritischem Treffer oder Todesstoß (Meter).
@export var heavy_shake_strength: float = 0.18
