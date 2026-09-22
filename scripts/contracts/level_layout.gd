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
