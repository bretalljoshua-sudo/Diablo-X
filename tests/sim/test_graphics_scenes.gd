extends SimTest
## AP1: Grafik-Testszenen bauen Licht, Materialien und Gegner auf.


func after_each() -> void:
	Vfx.clear()


func test_graphics_test_decorates_level() -> void:
	var scene := await load_scene("graphics_test")
	var level := scene.get_node("Level") as Level
	await wait_process_frames(2)
	var lights := level.find_children("*", "OmniLight3D", true, false)
	var flickering := 0
	for light in lights:
		if light.get_node_or_null("Flicker") != null:
			flickering += 1
	assert_gt(flickering, 0, "Fackeln flackern")
	var player := level.player
	assert_not_null(
		player.get_node_or_null(NodePath(LightPresets.PLAYER_LIGHT_NAME)), "Spielerlicht"
	)
	Graphics.update_shadow_lights()
	assert_lte(Graphics.count_shadow_lights(), Graphics.get_preset().max_shadow_lights)
	assert_gt(Graphics.count_shadow_lights(), 0)
	var cells := level.find_children("Cells", "GridMap", true, false)[0] as GridMap
	var wall_id := cells.mesh_library.find_item_by_name("wall")
	var wall_material := cells.mesh_library.get_item_mesh(wall_id).surface_get_material(0)
	assert_true(wall_material is ShaderMaterial, "Wände blenden sich vor der Figur aus")


func test_graphics_test_showcase_triggers_effects() -> void:
	var scene := await load_scene("graphics_test")
	scene.call(&"showcase")
	assert_gt(Vfx.active_numbers().size(), 0)
	assert_gt(Vfx.loot_beam_count(), 0)
	assert_gt(Vfx.active_count(&"skill_war_cry"), 0)


func test_perf_scene_spawns_fifty_enemies() -> void:
	var scene := await load_scene("graphics_perf")
	assert_eq((scene.get("actors") as Array).size(), 50)
	await wait_seconds(0.5)
	assert_gt(Vfx.active_numbers().size(), 0, "laufende Treffer")


func test_benchmark_summary() -> void:
	var script: GDScript = load("res://debug/graphics_perf.gd")
	var times := PackedFloat32Array()
	for i in 99:
		times.append(1.0 / 100.0)
	times.append(0.05)
	var stats: Dictionary = script.summarize(times)
	assert_almost_eq(stats["avg_fps"], 100.0 / (0.99 + 0.05), 0.01)
	assert_almost_eq(stats["low_1_fps"], 20.0, 0.01)
	assert_almost_eq(stats["worst_ms"], 50.0, 0.01)
