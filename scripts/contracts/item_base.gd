class_name ItemBase
extends Resource
## Grundgegenstand, zum Beispiel „Rostiges Schwert“. Aus ihm entstehen ItemInstance-Objekte.

@export var id: StringName = &""
@export var display_name: String = ""
@export var slot: Enums.Slot = Enums.Slot.WEAPON
## Werte, die jeder Gegenstand dieser Art hat (zum Beispiel Schaden einer Waffe).
@export var base_stats: StatBlock
## Modell am Boden und an der Figur (von AP8), darf leer sein.
@export var model: PackedScene
@export var icon: Texture2D
## Größe im Inventar-Raster.
@export var grid_size: Vector2i = Vector2i(1, 1)
