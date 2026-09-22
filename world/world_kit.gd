class_name WorldKit
extends RefCounted
## Liefert die MeshLibrary für den Aufbau: die echte von AP8, sonst den Platzhalter.
## Die Zuordnung läuft über den Namen des Items (siehe docs/pakete/AP6.md).
## Fehlende Namen in der echten Bibliothek werden mit Platzhalter-Items aufgefüllt.

## Fester Pfad, unter dem AP8 den Baukasten liefert.
const REAL_PATH := "res://assets/world/world_kit.tres"

static var _library: MeshLibrary
## WorldTiles-ID → Item-ID in _library.
static var _item_ids: Dictionary[int, int] = {}


static func get_library() -> MeshLibrary:
	if _library == null:
		_load()
	return _library


## Item-ID in der geladenen Bibliothek für eine WorldTiles-ID (-1 = leer).
static func item_for(tile_id: int) -> int:
	if _library == null:
		_load()
	return _item_ids.get(tile_id, GridMap.INVALID_CELL_ITEM)


## Ob die echte Bibliothek von AP8 benutzt wird.
static func uses_real_kit() -> bool:
	return get_library() != PlaceholderKit.get_library()


static func _load() -> void:
	var placeholder := PlaceholderKit.get_library()
	_item_ids.clear()
	if not ResourceLoader.exists(REAL_PATH):
		_library = placeholder
		for id: int in WorldTiles.NAMES:
			_item_ids[id] = id
		return
	var real := load(REAL_PATH) as MeshLibrary
	if real == null:
		push_warning("WorldKit: %s ist keine MeshLibrary, nehme Platzhalter." % REAL_PATH)
		_library = placeholder
		for id: int in WorldTiles.NAMES:
			_item_ids[id] = id
		return
	_library = real.duplicate() as MeshLibrary
	var missing: PackedStringArray = []
	for id: int in WorldTiles.NAMES:
		var tile_name := WorldTiles.NAMES[id]
		var found := _library.find_item_by_name(tile_name)
		if found < 0:
			found = _library.get_last_unused_item_id()
			_library.create_item(found)
			_library.set_item_name(found, tile_name)
			_library.set_item_mesh(found, placeholder.get_item_mesh(id))
			_library.set_item_shapes(found, placeholder.get_item_shapes(id))
			missing.append(tile_name)
		_item_ids[id] = found
	if not missing.is_empty():
		push_warning("WorldKit: Platzhalter für fehlende Items: %s" % ", ".join(missing))
