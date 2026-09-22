extends Node3D
## PLATZHALTER-Spielerfigur für die Beute-Testszene (AP4): Grundwerte plus Ausrüstung.
## Die echte Spielerfigur baut AP2; dort rechnet der Stats-Dienst Ausrüstung ein.

## Grundwerte ohne Ausrüstung (die Standardwerte des Stats-Dienstes).
var base_stats: StatBlock
## Grundwerte plus Ausrüstung, liest der Stats-Dienst (Ersatzversion aus AP0).
var stats: StatBlock = StatBlock.new()

@onready var inventory: Inventory = $Inventory
@onready var equipment: Equipment = $Equipment


func _ready() -> void:
	base_stats = StatBlock.from_dict(Stats.DEFAULTS)
	equipment.stats_changed.connect(_recalculate)
	_recalculate()


func _recalculate() -> void:
	stats = equipment.apply_to(base_stats)
