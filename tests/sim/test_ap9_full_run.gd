extends GutTest
## „Fertig, wenn“ von AP9: Der RunBot spielt den ganzen Ablauf in einem eigenen Godot-Prozess,
## so schnell der Rechner kann (--fixed-fps): Dorf → Ebene 1 → Ebene 2 → Boss → Portal → Dorf,
## ab Stufe 1. Danach lädt ein zweiter Prozess den Spielstand („Weiter“), der Neustart übersteht.

const SAVE_FILE := "user://test_ap9_full_run.json"
## Obergrenze in Spiel-Frames (60 pro Sekunde): 25 Minuten Spielzeit.
const MAX_FRAMES := 90000
const GAME_SCENE := "res://encounters/game.tscn"


func _godot(args: PackedStringArray) -> String:
	var all := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://")])
	all.append_array(args)
	var output: Array = []
	OS.execute(OS.get_executable_path(), all, output, true)
	return "\n".join(output)


func _result(log_text: String) -> Dictionary:
	for line in log_text.split("\n"):
		if line.begins_with(GameSession.RESULT_PREFIX):
			var parsed: Variant = JSON.parse_string(line.trim_prefix(GameSession.RESULT_PREFIX))
			if parsed is Dictionary:
				return parsed
	return {}


func _script_errors(log_text: String) -> PackedStringArray:
	var errors := PackedStringArray()
	for line in log_text.split("\n"):
		if line.contains("SCRIPT ERROR") or line.contains("Parse Error"):
			errors.append(line)
	return errors


func test_bot_plays_the_whole_run_and_the_save_survives_a_restart() -> void:
	var save_path := ProjectSettings.globalize_path(SAVE_FILE)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var run_log := _godot(
		PackedStringArray(
			[
				"--fixed-fps",
				"60",
				"--quit-after",
				str(MAX_FRAMES),
				"--",
				"--scene=" + GAME_SCENE,
				"--new-game",
				"--bot",
				"--quit-after-run",
				"--save-path=" + save_path,
			]
		)
	)
	assert_eq(_script_errors(run_log), PackedStringArray(), "keine Skriptfehler im Durchlauf")
	var result := _result(run_log)
	assert_false(result.is_empty(), "Durchlauf geschafft und zurück im Dorf")
	if result.is_empty():
		var lines := run_log.split("\n")
		gut.p("\n".join(lines.slice(maxi(lines.size() - 40, 0))))
		return
	gut.p("Durchlauf: %s" % JSON.stringify(result))
	var progress: Dictionary = result["progress"]
	var bot: Dictionary = result["bot"]
	assert_eq(int(result["depth"]), World.VILLAGE_DEPTH, "über das Portal zurück im Dorf")
	assert_eq(int(progress["runs_completed"]), 1)
	assert_eq(int(progress["boss_kills"]), 1)
	assert_eq(int(result["boss_phase"]), 2, "Boss in Phase 2 gebracht")
	var levels: Array = bot["levels"]
	assert_gte(levels.size(), 3, "Ebene 1, Ebene 2 und Bossraum gespielt")
	assert_gte(int(result["level"]), 4, "Stufenaufstiege auf dem Weg")
	assert_between(float(result["run_sec"]), 180.0, 1500.0, "Dauer des Durchlaufs in Sekunden")
	assert_gt(int(bot["kills"]), 30, "Gegner besiegt")

	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	assert_eq(int(raw["version"]), SaveService.SAVE_VERSION)
	var saved: Dictionary = raw["data"]
	assert_eq(
		int((saved["skills"] as Dictionary)["level"]), int(result["level"]), "Stufe gespeichert"
	)
	assert_eq(
		int((saved["inventory"] as Dictionary)["gold"]), int(result["gold"]), "Gold gespeichert"
	)
	assert_gt((saved["equipment"] as Dictionary).size(), 0, "Ausrüstung gespeichert")

	var continue_log := _godot(
		PackedStringArray(
			[
				"--fixed-fps",
				"60",
				"--quit-after",
				"120",
				"--",
				"--scene=" + GAME_SCENE,
				"--continue",
				"--save-path=" + save_path,
			]
		)
	)
	assert_eq(_script_errors(continue_log), PackedStringArray())
	var expected := "Spielstand geladen (%s)" % SaveGame.summary(SaveGame.migrate(saved))
	assert_string_contains(continue_log, expected, "zweiter Start lädt denselben Stand")
	assert_string_contains(continue_log, "1 Durchlauf")
	DirAccess.remove_absolute(save_path)
