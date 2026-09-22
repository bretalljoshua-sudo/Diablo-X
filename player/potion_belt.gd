class_name PotionBelt
extends Node
## Heiltränke mit Ladungen. Besiegte Gegner füllen Ladungen wieder auf
## (kills_per_charge Gegner = 1 Ladung). Sendet EventBus.potion_charges_changed für das HUD.

signal charges_changed(charges: int, maximum: int, progress: float)
signal drunk(healed: float)

@export var max_charges: int = 4
@export_range(0.0, 1.0) var heal_ratio: float = 0.35
@export var cooldown: float = 1.0
@export var kills_per_charge: int = 3

var charges: int = 0
## Fortschritt zur nächsten Ladung (0 bis 1).
var progress: float = 0.0

var _cooldown_left: float = 0.0


func _ready() -> void:
	charges = max_charges
	EventBus.entity_died.connect(_on_entity_died)
	_emit()


func configure(config: PlayerConfig) -> void:
	max_charges = config.potion_max_charges
	heal_ratio = config.potion_heal_ratio
	cooldown = config.potion_cooldown
	kills_per_charge = config.potion_kills_per_charge
	charges = max_charges
	progress = 0.0
	_emit()


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func get_cooldown_left() -> float:
	return _cooldown_left


func can_drink() -> bool:
	var health := Components.health(get_parent())
	return (
		charges > 0
		and _cooldown_left <= 0.0
		and health != null
		and not health.is_dead()
		and health.current < health.maximum
	)


## Trinkt einen Trank. Liefert false, wenn keine Ladung da ist, die Abklingzeit läuft
## oder das Leben voll ist.
func drink() -> bool:
	if not can_drink():
		return false
	var health := Components.health(get_parent())
	var healed := health.heal(health.maximum * heal_ratio)
	charges -= 1
	_cooldown_left = cooldown
	drunk.emit(healed)
	_emit()
	return true


## Fügt Fortschritt hinzu (1.0 = eine ganze Ladung).
func add_progress(amount: float) -> void:
	if charges >= max_charges:
		progress = 0.0
		return
	progress += amount
	while progress >= 0.999 and charges < max_charges:
		progress -= 1.0
		charges += 1
	progress = 0.0 if charges >= max_charges else maxf(progress, 0.0)
	_emit()


func refill() -> void:
	charges = max_charges
	progress = 0.0
	_emit()


func _on_entity_died(entity: Node3D, killer: Node3D) -> void:
	var owner_entity := get_parent()
	if killer != null and killer == owner_entity and entity != owner_entity:
		add_progress(1.0 / maxf(kills_per_charge, 1))


func _emit() -> void:
	charges_changed.emit(charges, max_charges, progress)
	if get_parent() == Game.player and Game.player != null:
		EventBus.potion_charges_changed.emit(charges, max_charges, progress)
