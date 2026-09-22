extends StaticBody3D
## BEISPIELGEGNER für die UI-Testszene (AP7): Trainingspuppe mit Leben, Namen und Elite-Kennung.
## Sendet EventBus.entity_health_changed wie später die HealthComponent aus AP2.

@export var display_name: String = "Trainingspuppe"
@export var is_elite: bool = false
@export var max_health: float = 100.0

var health: float = 100.0


func _ready() -> void:
	health = max_health


func take_damage(amount: float) -> bool:
	if health <= 0.0:
		return false
	health = maxf(health - amount, 0.0)
	EventBus.entity_health_changed.emit(self, health, max_health)
	if health <= 0.0:
		EventBus.entity_died.emit(self, Game.player)
		visible = false
		return true
	return false


func revive() -> void:
	health = max_health
	visible = true
	EventBus.entity_health_changed.emit(self, health, max_health)
