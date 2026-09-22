class_name SimTest
extends GutTest
## Grundlage für Simulationstests: lädt eine Szene headless, drückt Eingaben
## wie ein Spieler und wartet echte Frames ab.
##
## Beispiel:
##   extends SimTest
##   func test_player_moves() -> void:
##       var scene := await load_scene("combat_test")
##       await hold_action(&"move_up", 0.5)
##       assert_gt(...)


## Lädt eine Testszene (Name aus debug/ oder res://-Pfad), hängt sie ein und wartet
## zwei Frames, damit _ready() überall gelaufen ist.
func load_scene(scene: String) -> Node:
	var path := Game.resolve_scene_path(scene)
	assert_ne(path, "", "Szene '%s' existiert" % scene)
	if path.is_empty():
		return null
	var instance := (load(path) as PackedScene).instantiate()
	add_child_autofree(instance)
	await wait_process_frames(2)
	return instance


## Hält eine Eingabe-Aktion für die angegebene Zeit gedrückt.
func hold_action(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await wait_seconds(seconds)
	Input.action_release(action)
	await wait_process_frames(1)


## Drückt eine Aktion einmal kurz (ein Frame).
func tap_action(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await wait_process_frames(1)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await wait_process_frames(1)
