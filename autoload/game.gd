extends Node
## Spielzustand und Szenenwechsel. Den Ablauf Dorf → Dungeon → Boss baut AP9 hier aus.

signal scene_changed(scene_name: String)

## Aktuelle Spielerfigur, setzt die Spielerszene (AP2) in _ready().
var player: Node3D
## Name der zuletzt über change_scene() geladenen Szene.
var current_scene_name: String = ""


## Wechselt zu einer Szene. Akzeptiert einen Pfad (res://…) oder den Namen
## einer Testszene aus debug/, zum Beispiel "test_room".
func change_scene(scene: String) -> Error:
	var path := resolve_scene_path(scene)
	if path.is_empty():
		push_error("Game: Szene '%s' nicht gefunden." % scene)
		return ERR_FILE_NOT_FOUND
	player = null
	current_scene_name = path.get_file().get_basename()
	var err := get_tree().change_scene_to_file(path)
	if err == OK:
		scene_changed.emit(current_scene_name)
	return err


## Macht aus "combat_test" den Pfad res://debug/combat_test.tscn.
## Liefert "" zurück, wenn es die Szene nicht gibt.
static func resolve_scene_path(scene: String) -> String:
	var candidates: Array[String] = []
	if scene.begins_with("res://"):
		candidates.append(scene)
	else:
		candidates.append("res://debug/%s.tscn" % scene)
		candidates.append("res://debug/%s/%s.tscn" % [scene, scene])
	for candidate in candidates:
		if ResourceLoader.exists(candidate):
			return candidate
	return ""


## Alle Testszenen in debug/ (für Fehlermeldungen und die Debug-Anzeige).
static func list_debug_scenes() -> PackedStringArray:
	var names := PackedStringArray()
	for file in ResourceLoader.list_directory("res://debug"):
		if file.ends_with(".tscn"):
			names.append(file.get_basename())
		elif (
			file.ends_with("/")
			and ResourceLoader.exists("res://debug/%s%s.tscn" % [file, file.trim_suffix("/")])
		):
			names.append(file.trim_suffix("/"))
	names.sort()
	return names
