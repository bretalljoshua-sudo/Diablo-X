extends SimTest
## Aufbau einer Ebene mit GridMap, Navigation und Übergängen (AP6).

const MAX_BUILD_MSEC := 1000


func after_each() -> void:
	World.current_depth = -1
	World.current_layout = null


func _make_level() -> Level:
	var level := (load("res://world/level.tscn") as PackedScene).instantiate() as Level
	level.auto_load = false
	add_child_autofree(level)
	return level


func test_build_is_fast_for_all_depths() -> void:
	var level := _make_level()
	World.start_new_run(4242)
	for depth in [0, 1, 2, 3]:
		level.load_depth(depth)
		assert_lt(level.last_build_msec, MAX_BUILD_MSEC, "Aufbau Ebene %d" % depth)
		assert_eq(World.current_depth, depth)
	# Die größte Ebene mehrmals mit verschiedenen Seeds.
	for i in 5:
		World.start_new_run(1000 + i)
		level.load_depth(2)
		assert_lt(level.last_build_msec, MAX_BUILD_MSEC, "Aufbau Ebene 2, Seed %d" % i)


func test_level_nodes_and_navigation_path() -> void:
	var level := _make_level()
	World.start_new_run(77)
	watch_signals(EventBus)
	var layout := level.load_depth(1)
	assert_signal_emitted(EventBus, "level_loaded")
	var cells := level.get_node("Geometry/Cells") as GridMap
	assert_eq(cells.get_used_cells().size(), layout.cells.size(), "alle Zellen gesetzt")
	var region := level.get_navigation_region()
	assert_gt(region.navigation_mesh.get_polygon_count(), 0, "Navigationsnetz gebacken")
	assert_eq(level.get_node("Geometry/Lights").get_child_count(), layout.lights.size())
	# Navigation braucht einige Physik-Takte, bis die Karte synchron ist.
	var map := region.get_navigation_map()
	var path := PackedVector3Array()
	for _i in 20:
		await wait_physics_frames(1)
		path = NavigationServer3D.map_get_path(map, layout.player_start, layout.exits[0], true)
		if path.size() > 1:
			break
	assert_gt(path.size(), 1, "Weg vom Start zum Ausgang")
	if path.size() > 1:
		assert_lt(path[path.size() - 1].distance_to(layout.exits[0]), 1.0, "Weg endet am Ausgang")


func test_player_is_placed_and_kept_between_levels() -> void:
	var level := _make_level()
	World.start_new_run(5)
	var layout := level.load_depth(1)
	var player := level.player
	assert_not_null(player)
	assert_true(player.global_position.is_equal_approx(layout.player_start))
	var layout2 := level.load_depth(2, 1)
	assert_eq(level.player, player, "dieselbe Figur")
	assert_true(player.global_position.is_equal_approx(layout2.player_start))
	# Zurück nach oben: Ankunft an der Treppe nach unten.
	var back := level.load_depth(1, 2)
	assert_true(player.global_position.is_equal_approx(back.markers[&"exit_arrival"]))


func test_travel_to_shows_loading_screen_and_emits() -> void:
	var level := _make_level()
	World.start_new_run(9)
	level.load_depth(0)
	watch_signals(EventBus)
	var travel: Signal = EventBus.level_loaded
	World.travel_to(1)
	assert_true(World.loading_screen.visible, "Ladebildschirm sichtbar")
	assert_eq(World.loading_screen.get_title(), World.depth_title(1))
	await wait_for_signal(travel, 3.0)
	assert_signal_emitted(EventBus, "level_transition_started")
	assert_signal_emitted(EventBus, "level_unloading")
	assert_eq(level.depth, 1)
	await wait_seconds(0.4)
	assert_false(World.loading_screen.visible, "Ladebildschirm wieder weg")
	assert_false(World.is_transitioning)


func test_walking_onto_exit_changes_level() -> void:
	var level := _make_level()
	World.start_new_run(31)
	var layout := level.load_depth(1)
	await wait_seconds(0.8)
	level.player.global_position = layout.exits[0]
	await wait_physics_frames(4)
	assert_true(World.is_transitioning or level.depth == 2, "Übergang gestartet")
	await wait_for_signal(EventBus.level_loaded, 3.0)
	assert_eq(level.depth, 2)
	await wait_seconds(0.4)


func test_boss_portal_opens_on_request() -> void:
	var level := _make_level()
	World.start_new_run(8)
	var layout := level.load_depth(3)
	var portal: ExitTrigger = null
	for trigger in level.get_node("Geometry/Triggers").get_children():
		if trigger.position.is_equal_approx(layout.markers[&"portal"]):
			portal = trigger
	assert_not_null(portal)
	assert_false(portal.active, "Portal zu, solange der Boss lebt")
	World.open_portal()
	assert_true(portal.active)
