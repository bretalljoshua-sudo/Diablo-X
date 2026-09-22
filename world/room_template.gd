class_name RoomTemplate
extends Resource
## Handgebaute Raumvorlage für den Dungeon-Generator (Dateien in data/world/rooms/).
##
## pattern beschreibt nur das Rauminnere, Zeile für Zeile (Zeile = z, Spalte = x).
## Wände um den Raum setzt der Generator selbst. Zeichen:
##   .  Boden            ,  Boden-Variante (gesprungen oder Schutt)
##   #  massiv (Wand)    P  Säule
##   S  Spawnpunkt       L  Feuerschale mit Licht
##   p  Requisite nach Zufall
##   B  Boss-Startpunkt  C  Belohnungstruhe (Marker)   O  Rückkehrportal
## Gänge docken an Randzellen mit Boden an. Alle Bodenzellen müssen zusammenhängen.

enum Kind { ROOM, BOSS }

@export var id: StringName = &""
@export var kind: Kind = Kind.ROOM
## Häufigkeit im Vergleich zu anderen Vorlagen.
@export var weight: float = 1.0
@export var min_depth: int = 1
@export var max_depth: int = 99
## Darf gedreht und gespiegelt werden.
@export var allow_transform: bool = true
@export var pattern: PackedStringArray = PackedStringArray()


func get_size() -> Vector2i:
	if pattern.is_empty():
		return Vector2i.ZERO
	return Vector2i(pattern[0].length(), pattern.size())


func char_at(cell: Vector2i) -> String:
	return pattern[cell.y][cell.x]


## Liefert eine gedrehte (quarter_turns × 90°) und optional gespiegelte Kopie des Musters.
func transformed(quarter_turns: int, mirror: bool) -> PackedStringArray:
	var rows := pattern.duplicate()
	if mirror:
		for i in rows.size():
			rows[i] = rows[i].reverse()
	for _i in posmod(quarter_turns, 4):
		rows = _rotate(rows)
	return rows


## Prüft das Muster. Liefert eine Fehlermeldung oder "" wenn alles stimmt.
func validate() -> String:
	var problem := _validate_shape()
	if problem.is_empty():
		problem = _validate_connected()
	if problem.is_empty() and kind == Kind.BOSS:
		var joined := "".join(pattern)
		if not ("B" in joined and "O" in joined):
			problem = "Bossraum braucht B und O"
	return "" if problem.is_empty() else "%s: %s" % [id, problem]


func _validate_shape() -> String:
	var size := get_size()
	if size.x < 2 or size.y < 2:
		return "Muster zu klein"
	for row in pattern:
		if row.length() != size.x:
			return "Zeilen unterschiedlich lang"
		for c in row:
			if not c in ".,#PSLpBCO":
				return "unbekanntes Zeichen '%s'" % c
	return ""


func _validate_connected() -> String:
	var size := get_size()
	var walkable: Array[Vector2i] = []
	for z in size.y:
		for x in size.x:
			if is_walkable_char(pattern[z][x]):
				walkable.append(Vector2i(x, z))
	if walkable.is_empty():
		return "kein Boden"
	var seen := {walkable[0]: true}
	var queue: Array[Vector2i] = [walkable[0]]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for dir in WorldTiles.DIRECTIONS:
			var next: Vector2i = cell + dir
			if next in walkable and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return "" if seen.size() == walkable.size() else "Boden hängt nicht zusammen"


static func is_walkable_char(c: String) -> bool:
	return c in ".,SpBCO"


## Dreht ein Muster um 90° im Uhrzeigersinn (von oben gesehen).
static func _rotate(rows: PackedStringArray) -> PackedStringArray:
	var height := rows.size()
	var width := rows[0].length()
	var result := PackedStringArray()
	for x in width:
		var line := ""
		for z in range(height - 1, -1, -1):
			line += rows[z][x]
		result.append(line)
	return result
