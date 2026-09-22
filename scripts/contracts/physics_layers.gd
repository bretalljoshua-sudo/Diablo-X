class_name PhysicsLayers
## Physik-Ebenen (3D). Die Namen stehen auch in project.godot unter layer_names.
## Werte sind Bitmasken für collision_layer und collision_mask.

## Wände, Boden, Hindernisse (StaticBody3D, GridMap).
const WORLD := 1 << 0
## Körper der Spielerfigur.
const PLAYER := 1 << 1
## Körper der Gegner und Trainingspuppen.
const ENEMY := 1 << 2
## Trefferflächen (HurtboxComponent), werden von Angriffen und der Mausauswahl gesucht.
const HURTBOX := 1 << 3
## Beute am Boden (GroundItem, AP4), wird von der Mausauswahl zum Aufsammeln gesucht.
const LOOT := 1 << 4
