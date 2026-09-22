extends GutTest
## AP8: Die Asset-Galerie baut Raum und Figuren und schaltet durch alle Animationen.


func _gallery() -> Node3D:
	var gallery := (load("res://debug/asset_gallery.tscn") as PackedScene).instantiate() as Node3D
	add_child_autofree(gallery)
	return gallery


func test_gallery_builds_room_and_figures() -> void:
	var gallery := _gallery()
	var figures: Array[CharacterModel] = gallery.call(&"figures")
	assert_eq(figures.size(), 5)
	var cells := gallery.get_node(^"Cells") as GridMap
	assert_gt(cells.get_used_cells().size(), 40, "Raum aus dem Baukasten")
	assert_true(WorldKit.uses_real_kit())


func test_space_steps_through_every_animation() -> void:
	var gallery := _gallery()
	await wait_process_frames(2)
	var figures: Array[CharacterModel] = gallery.call(&"figures")
	var seen: Array[StringName] = []
	for step in 14:
		var anim: StringName = gallery.call(&"current_animation")
		seen.append(anim)
		if anim == &"death":
			assert_true(figures[0].is_dead(), "Tod wird gezeigt")
		elif anim in CharacterModel.ACTIONS and anim != &"attack_3":
			await wait_process_frames(1)
			assert_true(figures[0].is_busy(), "%s läuft" % anim)
		var press := InputEventKey.new()
		press.keycode = KEY_SPACE
		press.pressed = true
		gallery.call(&"_unhandled_input", press)
	assert_eq(seen.size(), 14)
	assert_eq(gallery.call(&"current_animation"), &"idle", "beginnt wieder von vorn")
	assert_false(figures[0].is_dead(), "Figuren stehen wieder auf")
