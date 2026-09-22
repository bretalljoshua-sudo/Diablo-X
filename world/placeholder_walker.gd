class_name PlaceholderWalker
extends CharacterBody3D
## Einfache Ersatzfigur für Ebenen ohne echte Spielerfigur (AP2): Kapsel, die per Linksklick
## über die Navigation läuft oder mit WASD gesteuert wird. Nur zum Testen der Welt.

@export var speed: float = 7.0

var _agent: NavigationAgent3D


func _init() -> void:
	name = "PlaceholderWalker"
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = PhysicsLayers.WORLD
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.45
	capsule_mesh.height = 1.8
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.75, 0.2, 0.15)
	capsule_mesh.material = material
	mesh.mesh = capsule_mesh
	mesh.position = Vector3(0, 0.9, 0)
	add_child(mesh)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 2.5, 0)
	glow.light_color = Color(0.8, 0.85, 1.0)
	glow.light_energy = 0.8
	glow.omni_range = 7.0
	add_child(glow)
	_agent = NavigationAgent3D.new()
	_agent.radius = LevelBuilder.AGENT_RADIUS
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.4
	add_child(_agent)


func _ready() -> void:
	add_to_group(&"player")
	_agent.target_position = global_position


func _physics_process(_delta: float) -> void:
	if Input.is_action_pressed(&"primary_action"):
		var rig := CameraRig.get_active()
		if rig != null:
			var point := rig.screen_to_ground(get_viewport().get_mouse_position())
			if point != Vector3.INF:
				_agent.target_position = point
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var direction := Vector3.ZERO
	if input != Vector2.ZERO:
		# Kamera schaut schräg (45°), WASD soll bildschirmbezogen laufen.
		direction = Vector3(input.x, 0, input.y).rotated(Vector3.UP, deg_to_rad(45.0))
		_agent.target_position = global_position
	elif not _agent.is_navigation_finished():
		direction = global_position.direction_to(_agent.get_next_path_position())
		direction.y = 0.0
	velocity = direction.normalized() * speed
	move_and_slide()
	global_position.y = 0.0


## Setzt die Figur ohne Laufweg an eine Stelle (nach einem Ebenenwechsel).
func teleport(target: Vector3) -> void:
	global_position = target
	velocity = Vector3.ZERO
	_agent.target_position = target
