extends GutTest


func test_screen_to_ground_hits_plane() -> void:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	await wait_process_frames(1)
	var center := rig.get_viewport().get_visible_rect().size / 2.0
	var point := rig.screen_to_ground(center)
	assert_ne(point, Vector3.INF)
	assert_almost_eq(point.y, 0.0, 0.001)
	# Die Kamera schaut auf ihren Ankerpunkt, die Bildmitte liegt also nahe am Ursprung.
	assert_almost_eq(point, Vector3.ZERO, Vector3.ONE * 0.5)


func test_get_active_finds_rig() -> void:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	await wait_process_frames(1)
	assert_eq(CameraRig.get_active(), rig)


func test_shake_does_not_move_anchor() -> void:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.shake(0.5, 0.1)
	await wait_seconds(0.2)
	assert_eq(rig.global_position, Vector3.ZERO)
