extends Node
## Startszene (Hauptszene). Lädt die Szene aus --scene=<name> oder die Standardszene.
##
## Beispiele:
##   godot --path . -- --scene=combat_test     Testszene res://debug/combat_test.tscn
##   SpielJBR.exe --scene=combat_test           dasselbe im Windows-Build
##   godot --path . -- --list-scenes            vorhandene Testszenen ausgeben

## Szene ohne --scene. AP9 stellt später auf den Titelbildschirm um.
const DEFAULT_SCENE := "test_room"


func _ready() -> void:
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if args.has("--list-scenes"):
		print("Testszenen: %s" % ", ".join(Game.list_debug_scenes()))
		get_tree().quit()
		return
	var scene_name := parse_scene_arg(args)
	if scene_name.is_empty():
		scene_name = DEFAULT_SCENE
	if Game.resolve_scene_path(scene_name).is_empty():
		push_error(
			(
				"Testszene '%s' gibt es nicht. Vorhanden: %s"
				% [scene_name, ", ".join(Game.list_debug_scenes())]
			)
		)
		scene_name = DEFAULT_SCENE
	print("Starte Szene: %s" % scene_name)
	Game.change_scene.call_deferred(scene_name)


## Liest den Wert von --scene=<name> aus den Argumenten, sonst "".
static func parse_scene_arg(args: PackedStringArray) -> String:
	for arg in args:
		if arg.begins_with("--scene="):
			return arg.trim_prefix("--scene=").strip_edges()
	return ""
