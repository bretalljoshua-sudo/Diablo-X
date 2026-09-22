extends Node3D
## Testraum aus AP0: Boden, Würfel, Licht und Kamera.
## Linksklick setzt eine Markierung auf den Boden (prüft CameraRig.screen_to_ground()).

const MARKER_LIMIT := 20

@export var spin_speed: float = 0.6

var _markers: Array[Node3D] = []

@onready var _cube: Node3D = $Cube


func _process(delta: float) -> void:
	_cube.rotate_y(spin_speed * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"primary_action"):
		var rig := CameraRig.get_active()
		if rig == null:
			return
		var point := rig.screen_to_ground(get_viewport().get_mouse_position())
		if point != Vector3.INF:
			place_marker(point)
			rig.shake(0.15, 0.2)


func place_marker(point: Vector3) -> Node3D:
	var marker := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	marker.mesh = mesh
	marker.position = point + Vector3(0, 0.2, 0)
	add_child(marker)
	_markers.append(marker)
	if _markers.size() > MARKER_LIMIT:
		_markers.pop_front().queue_free()
	return marker
