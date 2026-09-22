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


# --- AP1: Kamera-Rig ---


func test_zoom_is_clamped_and_smooth() -> void:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	await wait_process_frames(1)
	rig.zoom_by(-100.0)
	await wait_seconds(0.6)
	assert_almost_eq(rig.get_current_distance(), rig.zoom_min, 0.2)
	rig.zoom_by(100.0)
	await wait_process_frames(1)
	assert_lt(rig.get_current_distance(), rig.zoom_max, "Zoom springt nicht, er gleitet")
	await wait_seconds(0.8)
	assert_almost_eq(rig.get_current_distance(), rig.zoom_max, 0.2)


func test_setting_distance_overrides_zoom_range() -> void:
	# world_test setzt für die Übersicht einen Abstand weit über zoom_max.
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.distance = 80.0
	await wait_seconds(0.8)
	assert_almost_eq(rig.get_current_distance(), 80.0, 1.0)


func test_follows_target_smoothly() -> void:
	var target := Node3D.new()
	add_child_autofree(target)
	var rig := CameraRig.new()
	rig.target = target
	add_child_autofree(rig)
	await wait_process_frames(1)
	target.global_position = Vector3(3, 0, 0)
	await wait_process_frames(2)
	assert_gt(rig.global_position.x, 0.0, "Kamera folgt")
	assert_lt(rig.global_position.x, 3.0, "aber weich, nicht sofort")
	await wait_seconds(1.5)
	assert_almost_eq(rig.global_position.x, 3.0, 0.05)


func test_snap_to_target_after_teleport() -> void:
	var target := Node3D.new()
	add_child_autofree(target)
	var rig := CameraRig.new()
	rig.target = target
	add_child_autofree(rig)
	await wait_process_frames(1)
	target.global_position = Vector3(40, 0, -20)
	rig.snap_to_target()
	assert_eq(rig.global_position, Vector3(40, 0, -20))


func test_shake_decays_and_is_capped() -> void:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.shake(5.0, 0.2)
	assert_almost_eq(rig.get_shake_strength(), rig.max_shake, 0.001, "gedeckelt")
	rig.shake(0.1, 1.0)
	assert_almost_eq(
		rig.get_shake_strength(), rig.max_shake, 0.001, "schwächerer Stoß ersetzt nicht"
	)
	await wait_seconds(0.3)
	assert_eq(rig.get_shake_strength(), 0.0)


func test_shake_moves_camera_but_not_anchor() -> void:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	await wait_process_frames(1)
	var rest := rig.camera.position
	rig.shake(0.6, 1.0)
	var moved := false
	for i in 10:
		await wait_process_frames(1)
		moved = moved or rig.camera.position.distance_to(rest) > 0.01
	assert_true(moved, "Kamera wackelt")
	assert_eq(rig.global_position, Vector3.ZERO)
