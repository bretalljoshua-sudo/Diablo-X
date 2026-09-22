extends SimTest
## Simulationstest für den Testraum aus AP0.


func test_test_room_loads_with_camera_and_floor() -> void:
	var room := await load_scene("test_room")
	assert_not_null(room.get_node_or_null("Floor"), "Boden vorhanden")
	assert_not_null(room.get_node_or_null("Cube"), "Würfel vorhanden")
	var rig := CameraRig.get_active()
	assert_not_null(rig, "Kamera registriert sich in der Gruppe")
	assert_true(rig.camera.current, "Kamera ist aktiv")


func test_cube_spins() -> void:
	var room := await load_scene("test_room")
	var cube := room.get_node("Cube") as Node3D
	var before := cube.rotation.y
	await wait_process_frames(10)
	assert_ne(cube.rotation.y, before, "Würfel dreht sich")


func test_marker_is_placed_on_ground() -> void:
	var room := await load_scene("test_room")
	var marker: Node3D = room.place_marker(Vector3(2, 0, 3))
	assert_almost_eq(marker.position, Vector3(2, 0.2, 3), Vector3.ONE * 0.001)
