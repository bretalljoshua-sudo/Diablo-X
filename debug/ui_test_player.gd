extends Node3D
## PLATZHALTER-Spieler für die UI-Testszene (AP7): läuft mit WASD, hat Leben, Heiltränke,
## Inventar und Ausrüstung. Sendet die HUD-Signale so, wie es später AP2 tut.

const SPEED := 6.0
const POTION_HEAL := 0.35
const POTION_RECHARGE := 6.0

var base_stats: StatBlock
## Grundwerte plus Ausrüstung, liest der Stats-Dienst (Ersatzversion aus AP0).
var stats: StatBlock = StatBlock.new()
var health: float = 180.0
var potions: int = 3
var potions_max: int = 4
var potion_progress: float = 0.0

@onready var inventory: Inventory = $Inventory
@onready var equipment: Equipment = $Equipment


func _ready() -> void:
	base_stats = StatBlock.from_dict(Stats.DEFAULTS)
	base_stats.set_value(Enums.Stat.MAX_LIFE, 250.0)
	equipment.stats_changed.connect(_recalculate)
	_recalculate()
	_send_potions()


func get_max_health() -> float:
	return stats.get_value(Enums.Stat.MAX_LIFE, 250.0)


func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	_send_health()


func drink_potion() -> bool:
	if potions <= 0:
		return false
	potions -= 1
	health = minf(health + get_max_health() * POTION_HEAL, get_max_health())
	_send_health()
	_send_potions()
	return true


func _physics_process(delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if input != Vector2.ZERO:
		# Bewegung relativ zur isometrischen Kamera (45° gedreht).
		var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, deg_to_rad(-45.0))
		position += dir * SPEED * delta
		look_at(global_position + dir, Vector3.UP)
	if potions < potions_max:
		potion_progress += delta / POTION_RECHARGE
		if potion_progress >= 1.0:
			potion_progress = 0.0
			potions += 1
		_send_potions()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"potion"):
		drink_potion()
		get_viewport().set_input_as_handled()


func _recalculate() -> void:
	stats = equipment.apply_to(base_stats)
	health = minf(health, get_max_health())
	_send_health()


func _send_health() -> void:
	EventBus.player_health_changed.emit(health, get_max_health())


func _send_potions() -> void:
	EventBus.potion_charges_changed.emit(potions, potions_max, potion_progress)
