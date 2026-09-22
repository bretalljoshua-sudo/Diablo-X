extends Node
## Speichert und lädt den Spielstand als JSON. Inhalt und Aufbau des Spielstands legt AP9 fest.

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://savegame.json"

var save_path: String = DEFAULT_PATH


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## Speichert data zusammen mit der Versionsnummer.
func save_game(data: Dictionary) -> Error:
	var payload := {"version": SAVE_VERSION, "data": data}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: kann %s nicht schreiben." % save_path)
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	return OK


## Lädt den Spielstand. Leeres Dictionary, wenn keiner da oder er unlesbar ist.
func load_game() -> Dictionary:
	if not has_save():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary or not parsed.has("data"):
		push_error("SaveService: Spielstand %s ist beschädigt." % save_path)
		return {}
	if int(parsed.get("version", 0)) > SAVE_VERSION:
		push_warning("SaveService: Spielstand ist neuer als dieses Spiel.")
	return parsed["data"]


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(save_path)
