extends SimTest
## Titelbildschirm (AP9): Startszene ohne --scene, Weiter nur mit Spielstand, Neues Spiel fragt
## vor dem Überschreiben nach.

const TEST_SAVE := "user://test_ap9_title.json"

var _previous_path: String
var _launched: int = 0


func before_each() -> void:
	_previous_path = SaveService.save_path
	SaveService.save_path = TEST_SAVE
	SaveService.delete_save()
	_launched = 0
	GameSession.launch_mode = GameSession.LaunchMode.NEW_GAME


func after_each() -> void:
	SaveService.delete_save()
	SaveService.save_path = _previous_path
	GameSession.launch_mode = GameSession.LaunchMode.NEW_GAME


func _load_title() -> TitleScreen:
	var title: TitleScreen = await load_scene("res://encounters/title_screen.tscn")
	title.launcher = func() -> void: _launched += 1
	return title


func test_main_scene_opens_the_title_screen() -> void:
	var main := load("res://main.gd")
	var scene: String = main.get(&"DEFAULT_SCENE")
	assert_eq(scene, "res://encounters/title_screen.tscn")
	assert_eq(Game.resolve_scene_path(scene), scene)
	assert_eq(
		Game.resolve_scene_path("test_room"),
		"res://debug/test_room.tscn",
		"Testraum bleibt über --scene"
	)


func test_without_save_only_new_game() -> void:
	var title := await _load_title()
	assert_true(title.continue_button.disabled, "Weiter ohne Spielstand gesperrt")
	assert_false(title.new_game_button.disabled)
	title.start_new_game()
	assert_eq(_launched, 1, "Neues Spiel startet sofort")
	assert_eq(GameSession.launch_mode, GameSession.LaunchMode.NEW_GAME)


func test_with_save_continue_shows_summary_and_new_game_asks() -> void:
	SaveService.save_game({"format": 1, "skills": {"level": 7}, "inventory": {"gold": 120}})
	var title := await _load_title()
	assert_false(title.continue_button.disabled, "Weiter mit Spielstand")
	var detail := title.continue_button.get_node(^"Detail") as Label
	assert_string_contains(detail.text, "Stufe 7")
	title.continue_game()
	assert_eq(_launched, 1)
	assert_eq(GameSession.launch_mode, GameSession.LaunchMode.CONTINUE)
	title.start_new_game()
	assert_eq(_launched, 1, "erst nachfragen")
	assert_true(title.confirm_dialog.visible, "Nachfrage vor dem Überschreiben")
	title.confirm_dialog.confirmed.emit()
	assert_eq(_launched, 2)
	assert_eq(GameSession.launch_mode, GameSession.LaunchMode.NEW_GAME)
