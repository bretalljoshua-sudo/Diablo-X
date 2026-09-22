class_name GameSounds
extends RefCounted
## Feste Klänge des Spiels (AP8). Jeder Klang ist ein AudioStreamRandomizer mit Varianten.
##
## Beispiel (Beute fällt):
##   GameSounds.play_at(GameSounds.LOOT_DROP_RARE, drop_position, self)
## Neu bauen: assets/tools/synth_sounds.py, dann assets/tools/build_sounds.gd.

const FOOTSTEP: AudioStream = preload("res://assets/audio/footstep.tres")
## Waffe schwingt (Nah- oder Fernkampf löst aus).
const SWING: AudioStream = preload("res://assets/audio/swing.tres")
## Waffe trifft einen Körper.
const IMPACT: AudioStream = preload("res://assets/audio/impact.tres")
## Figur wird getroffen (Schmerzlaut).
const HURT: AudioStream = preload("res://assets/audio/hurt.tres")
const DEATH: AudioStream = preload("res://assets/audio/death.tres")
## Skelett zerfällt.
const BONE_BREAK: AudioStream = preload("res://assets/audio/bone_break.tres")
const CAST: AudioStream = preload("res://assets/audio/cast.tres")
const LOOT_DROP: AudioStream = preload("res://assets/audio/loot_drop.tres")
const LOOT_DROP_RARE: AudioStream = preload("res://assets/audio/loot_drop_rare.tres")
const LOOT_DROP_LEGENDARY: AudioStream = preload("res://assets/audio/loot_drop_legendary.tres")
const LOOT_PICKUP: AudioStream = preload("res://assets/audio/loot_pickup.tres")
const GOLD_PICKUP: AudioStream = preload("res://assets/audio/gold_pickup.tres")

## Bus für Effekte (Lautstärke in den Einstellungen); fehlt er, läuft alles über Master.
const EFFECTS_BUS := &"Effects"


static func bus() -> StringName:
	return EFFECTS_BUS if AudioServer.get_bus_index(EFFECTS_BUS) >= 0 else &"Master"


## Spielt einen Klang einmal an einer Stelle im Raum. Der Spieler hängt an context.get_tree()
## und löscht sich nach dem Abspielen selbst. Gibt den Spieler zurück (null ohne Baum).
static func play_at(
	stream: AudioStream, position: Vector3, context: Node, volume_db: float = 0.0
) -> AudioStreamPlayer3D:
	if stream == null or context == null or not context.is_inside_tree():
		return null
	var root := context.get_tree().current_scene
	if root == null:
		root = context.get_tree().root
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = bus()
	player.finished.connect(player.queue_free)
	root.add_child(player)
	player.global_position = position
	player.play()
	return player
