extends GutTest

const TEST_PATH := "user://test_savegame.json"


func before_each() -> void:
	SaveService.save_path = TEST_PATH
	SaveService.delete_save()


func after_each() -> void:
	SaveService.delete_save()
	SaveService.save_path = SaveService.DEFAULT_PATH


func test_save_and_load_roundtrip() -> void:
	assert_false(SaveService.has_save())
	assert_eq(SaveService.save_game({"gold": 120, "level": 3}), OK)
	assert_true(SaveService.has_save())
	var data := SaveService.load_game()
	assert_eq(int(data["gold"]), 120)
	assert_eq(int(data["level"]), 3)


func test_load_without_save_is_empty() -> void:
	assert_eq(SaveService.load_game(), {})
