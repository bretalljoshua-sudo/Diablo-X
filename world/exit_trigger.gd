class_name ExitTrigger
extends Area3D
## Übergang zu einer anderen Ebene (Treppe, Gruft-Eingang, Portal).
## Betritt die Spielerfigur den Bereich, startet World.travel_to(target_depth).

## Ziel-Ebene wie LevelConfig.depth (0 = Dorf).
@export var target_depth: int = 1
## Nach dem Laden kurz gesperrt, damit man nicht sofort zurückfällt.
@export var arm_delay: float = 0.6
@export var active: bool = true

var _arm_left: float = 0.0


func _init() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitorable = false


func _ready() -> void:
	_arm_left = arm_delay
	body_entered.connect(_on_body_entered)


## Die Sperre läuft in Spielzeit (auch in beschleunigten Tests). Steht die Figur beim Scharfschalten
## schon im Bereich, zählt das wie Betreten.
func _physics_process(delta: float) -> void:
	if _arm_left <= 0.0:
		set_physics_process(false)
		return
	_arm_left -= delta
	if _arm_left <= 0.0:
		for body in get_overlapping_bodies():
			_on_body_entered(body)


static func create(target: Vector3, depth: int, radius: float = 1.4) -> ExitTrigger:
	var trigger := ExitTrigger.new()
	trigger.position = target
	trigger.target_depth = depth
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = 2.0
	shape.shape = cylinder
	shape.position = Vector3(0, 1.0, 0)
	trigger.add_child(shape)
	return trigger


static func is_player(body: Node) -> bool:
	return body != null and (body == Game.player or body.is_in_group(&"player"))


func _on_body_entered(body: Node3D) -> void:
	if active and is_player(body) and _arm_left <= 0.0:
		World.travel_to(target_depth)
