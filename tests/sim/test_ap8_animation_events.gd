extends GutTest
## AP8: Trefferzeitpunkte feuern headless im laufenden AnimationTree, Aktionen enden von selbst.


func _spawn(character: String) -> CharacterModel:
	var scene := load("res://assets/characters/%s.tscn" % character) as PackedScene
	var model := scene.instantiate() as CharacterModel
	add_child_autofree(model)
	return model


func test_hit_frame_fires_once_at_the_right_time() -> void:
	var model := _spawn("warrior")
	await wait_process_frames(2)
	watch_signals(model)
	var expected := model.get_event_time(&"attack_1", &"hit")
	var start := Time.get_ticks_msec()
	model.play_action(&"attack_1")
	await wait_for_signal(model.hit_frame, 3.0)
	var elapsed := (Time.get_ticks_msec() - start) / 1000.0
	assert_signal_emit_count(model, "hit_frame", 1)
	# Echtzeit headless schwankt; der Treffer darf nicht vor dem Zeitpunkt kommen.
	assert_gt(elapsed, expected * 0.8, "Treffer nicht zu früh")
	await wait_for_signal(model.action_finished, 3.0)
	assert_signal_emitted(model, "action_finished")
	assert_false(model.is_busy())
	await wait_process_frames(10)
	assert_signal_emit_count(model, "hit_frame", 1, "nur ein Treffer je Schlag")


func test_release_frame_fires_for_archer() -> void:
	var model := _spawn("skeleton_archer")
	await wait_process_frames(2)
	watch_signals(model)
	model.play_action(&"attack_1")
	await wait_for_signal(model.release_frame, 3.0)
	assert_signal_emitted(model, "release_frame")
	assert_signal_not_emitted(model, "hit_frame")


func test_faster_attack_hits_sooner() -> void:
	var model := _spawn("skeleton_swarm")
	await wait_process_frames(2)
	var normal := model.get_event_time(&"attack_1", &"hit")
	var start := Time.get_ticks_msec()
	model.play_action(&"attack_1", 2.0)
	await wait_for_signal(model.hit_frame, 3.0)
	var elapsed := (Time.get_ticks_msec() - start) / 1000.0
	assert_lt(elapsed, normal, "doppeltes Tempo trifft früher als %.2f s" % normal)


func test_footsteps_while_running() -> void:
	var model := _spawn("warrior")
	await wait_process_frames(2)
	watch_signals(model)
	model.set_move_velocity(model.run_speed)
	await wait_seconds(1.5)
	assert_signal_emitted(model, "footstep")


func test_looping_action_needs_stop() -> void:
	var model := _spawn("warrior")
	await wait_process_frames(2)
	model.play_action(&"attack_3")  # Wirbelsturm, Schleife
	await wait_seconds(1.2)
	assert_true(model.is_busy(), "Wirbelsturm läuft weiter")
	model.stop_action()
	assert_false(model.is_busy())
	await wait_seconds(0.4)
	var playback := model.anim_tree.get(&"parameters/playback") as AnimationNodeStateMachinePlayback
	assert_eq(playback.get_current_node(), CharacterModel.LOCOMOTION_STATE)


func test_death_blocks_actions_until_revive() -> void:
	var model := _spawn("ghoul")
	await wait_process_frames(2)
	model.play_death()
	assert_true(model.is_dead())
	assert_false(model.play_action(&"attack_1"))
	model.revive()
	assert_false(model.is_dead())
	assert_true(model.play_action(&"attack_1"))
