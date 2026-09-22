extends GutTest
## Testszenen-Starter (main.gd) und Game.resolve_scene_path().

var _main: GDScript = load("res://main.gd")


func test_parse_scene_arg() -> void:
	assert_eq(_main.parse_scene_arg(PackedStringArray(["--scene=combat_test"])), "combat_test")
	assert_eq(_main.parse_scene_arg(PackedStringArray(["--seed=3"])), "")


func test_resolve_known_and_unknown_scenes() -> void:
	assert_eq(Game.resolve_scene_path("test_room"), "res://debug/test_room.tscn")
	assert_eq(Game.resolve_scene_path("res://debug/test_room.tscn"), "res://debug/test_room.tscn")
	assert_eq(Game.resolve_scene_path("does_not_exist"), "")


func test_list_debug_scenes_contains_test_room() -> void:
	assert_has(Game.list_debug_scenes(), "test_room")


func test_default_scene_exists() -> void:
	assert_ne(Game.resolve_scene_path(_main.DEFAULT_SCENE), "")
