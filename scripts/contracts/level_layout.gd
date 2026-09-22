class_name LevelLayout
extends Resource
## Ergebnis von World.generate(): alles, was zum Aufbau einer Ebene nötig ist.

@export var seed: int = 0
@export var player_start: Vector3 = Vector3.ZERO
@export var spawn_points: Array[Vector3] = []
@export var exits: Array[Vector3] = []
@export var lights: Array[Vector3] = []
## Begehbarer Bereich in Weltkoordinaten.
@export var bounds: AABB = AABB()
## GridMap-Zellen: Vector3i → Item-ID aus der MeshLibrary (AP8).
@export var cells: Dictionary[Vector3i, int] = {}

# --- Ergänzt von AP6 (Dungeon und Dorf) ---

## Ebene: 0 = Dorf, 1 und 2 = Dungeon-Ebenen, 3 = Bossraum (aus LevelConfig.depth).
@export var depth: int = 1
## Stilrichtung, aus LevelConfig.theme (&"catacombs", &"boss", &"village").
@export var theme: StringName = &""
## Größe einer Rasterzelle in Metern (GridMap.cell_size). Zelle (x, 0, z) hat ihre Mitte bei
## ((x + 0.5) * cell_size.x, 0, (z + 0.5) * cell_size.z).
@export var cell_size: Vector3 = Vector3(4, 4, 4)
## Drehung je Zelle in cells als GridMap-Orientierungsindex. Fehlt ein Eintrag, gilt 0.
@export var cell_orientations: Dictionary[Vector3i, int] = {}
## Zweite Ebene für Requisiten (Fässer, Fackeln, …): Zelle → Item-ID.
@export var props: Dictionary[Vector3i, int] = {}
## Drehung je Zelle in props als GridMap-Orientierungsindex. Fehlt ein Eintrag, gilt 0.
@export var prop_orientations: Dictionary[Vector3i, int] = {}
## Räume als Rechtecke im Zellraster (x, z). Index 0 ist der Startraum.
@export var rooms: Array[Rect2i] = []
## Verbindungen zwischen Räumen als Paare von Raum-Indizes (für Minikarte und Tests).
@export var room_links: Array[Vector2i] = []
## Zu jedem Eintrag in spawn_points der Index des Raums (für Gegnergruppen je Raum).
@export var spawn_rooms: Array[int] = []
## Index des Bossraums in rooms, -1 wenn es keinen gibt.
@export var boss_room: int = -1
## Rückweg zur vorigen Ebene (Treppe nach oben). Vector3.INF, wenn es keinen gibt.
@export var entrance: Vector3 = Vector3.INF
## Benannte Punkte für Szenen anderer Pakete, zum Beispiel &"merchant", &"stash",
## &"boss_spawn", &"boss_chest", &"boss_gate", &"portal".
@export var markers: Dictionary[StringName, Vector3] = {}
