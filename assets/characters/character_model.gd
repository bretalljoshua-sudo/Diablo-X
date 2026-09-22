class_name CharacterModel
extends Node3D
## Sichtbares, animiertes Modell einer Figur (AP8). Wurzel jeder Szene unter
## assets/characters/ (warrior.tscn, skeleton_swarm.tscn, ghoul.tscn, skeleton_archer.tscn,
## cultist_summoner.tscn). Spieler (AP2) und Gegner (AP3) hängen die Szene als Kind an ihren
## CharacterBody3D und steuern sie nur über diese Schnittstelle.
##
## Aufbau: Model (importiertes KayKit-glb mit Skelett %GeneralSkeleton) und AnimationTree mit
## dem gemeinsamen Zustandsautomaten assets/animations/character_state_machine.tres und der
## Bibliothek der Figur (assets/animations/libraries/<figur>.tres). Alle Bibliotheken nutzen
## dieselben Namen:
##   Fortbewegung: idle, walk, run (gemischt über set_move_velocity() oder set_move_speed())
##   Aktionen:     attack_1 … attack_4, cast, hit, dodge, spawn, block, interact, death
##
## Kurzformen für den Spieler aus AP2 (player.gd): play_action(&"attack", angriffe_pro_sekunde)
## spielt attack_1 genau in der Dauer eines Angriffs, &"stunned" spielt hit, &"idle", &"walk"
## und &"run" beenden die laufende Aktion. set_move_speed(anteil) nimmt 0 bis 1 der
## Höchstgeschwindigkeit reference_max_speed.
##
## Trefferzeitpunkte liegen als Methodenspuren in den Clips und kommen hier als Signale an:
##   hit_frame      Waffe trifft (Nahkampf)   → jetzt Schaden austeilen
##   release_frame  Geschoss oder Zauber löst sich
##   footstep       ein Fuß setzt auf

## Jedes Ereignis aus einer Methodenspur ("hit", "release", "footstep").
signal anim_event(event: StringName)
signal hit_frame
signal release_frame
signal footstep
## Eine Aktion ist zu Ende (auch wenn sie unterbrochen wurde).
signal action_finished(action: StringName)

const LOCOMOTION_STATE := &"locomotion"
const ACTIONS: Array[StringName] = [
	&"attack_1",
	&"attack_2",
	&"attack_3",
	&"attack_4",
	&"cast",
	&"hit",
	&"dodge",
	&"spawn",
	&"block",
	&"interact",
	&"death",
]
## Kurzformen → Aktion (siehe oben).
const ACTION_ALIASES := {&"attack": &"attack_1", &"stunned": &"hit"}
const LOCOMOTION_NAMES: Array[StringName] = [&"idle", &"walk", &"run"]
## Die Lauf-Animation wird höchstens so viel schneller abgespielt, sonst wirkt sie hektisch.
const MAX_LOCOMOTION_SCALE := 1.8
const ACTION_DONE_CONDITION := &"parameters/conditions/action_done"
## Überblendzeit zurück zur Fortbewegung; so früh vor dem Clip-Ende wird zurückgeschaltet.
const RETURN_BLEND := 0.15
## Mindestabstand zweier Schrittgeräusche (Gehen und Laufen werden gemischt).
const FOOTSTEP_MIN_INTERVAL := 0.2

## Geschwindigkeit in m/s, bei der die Geh-Animation ohne Rutschen passt.
@export var walk_speed: float = 0.6
## Geschwindigkeit in m/s, bei der die Lauf-Animation ohne Rutschen passt.
@export var run_speed: float = 2.45
## Höchstgeschwindigkeit in m/s für set_move_speed(anteil) (Krieger: MOVE_SPEED 6).
@export var reference_max_speed: float = 6.0
## Waffe für die rechte Hand (Knochen handslot.r), optional.
@export var weapon_right: PackedScene
## Waffe oder Schild für die linke Hand (Knochen handslot.l), optional.
@export var weapon_left: PackedScene
## Namen von Teilen des Modells, die ausgeblendet werden (zum Beispiel andere Waffen).
@export var hidden_parts: PackedStringArray = []
## Ersetzt die Farbtextur aller Teile (Umfärbungen wie Kultist oder Ghul).
@export var albedo_override: Texture2D
## Einfärbung aller Teile, Weiß = unverändert.
@export var tint: Color = Color.WHITE
@export var footstep_sound: AudioStream
@export var hit_sound: AudioStream
@export var death_sound: AudioStream

var _playback: AnimationNodeStateMachinePlayback
var _action: StringName = &""
var _action_left: float = 0.0
var _action_loops: bool = false
var _dead: bool = false
var _move_speed: float = 0.0
var _clock: float = 0.0
var _last_footstep: float = -1.0
var _audio: AudioStreamPlayer3D

@onready var model: Node3D = $Model
@onready var anim_tree: AnimationTree = $AnimationTree


func _ready() -> void:
	_playback = anim_tree.get(&"parameters/playback") as AnimationNodeStateMachinePlayback
	anim_tree.set(ACTION_DONE_CONDITION, false)
	_apply_looks()
	_attach_weapon(weapon_right, &"handslot.r", &"WeaponRight")
	_attach_weapon(weapon_left, &"handslot.l", &"WeaponLeft")
	_audio = AudioStreamPlayer3D.new()
	_audio.name = &"Audio"
	_audio.bus = &"Master"
	add_child(_audio)


func _process(delta: float) -> void:
	_clock += delta
	if _action.is_empty() or _action_loops or _dead:
		return
	_action_left -= delta
	if _action_left <= RETURN_BLEND:
		_finish_action()


## Fortbewegung als Anteil 0 bis 1 der Höchstgeschwindigkeit (Schnittstelle von AP2).
func set_move_speed(ratio: float) -> void:
	set_move_velocity(ratio * reference_max_speed)


## Fortbewegung in m/s. 0 = Stehen, walk_speed = Gehen, run_speed = Laufen.
## Schneller als run_speed spielt die Lauf-Animation schneller (bis MAX_LOCOMOTION_SCALE).
func set_move_velocity(speed: float) -> void:
	_move_speed = maxf(speed, 0.0)
	var blend := 0.0
	if _move_speed <= walk_speed:
		blend = _move_speed / walk_speed
	else:
		blend = 1.0 + clampf((_move_speed - walk_speed) / (run_speed - walk_speed), 0.0, 1.0)
	anim_tree.set(&"parameters/locomotion/blend/blend_position", blend)
	var scale := clampf(_move_speed / run_speed, 1.0, MAX_LOCOMOTION_SCALE)
	anim_tree.set(&"parameters/locomotion/speed/scale", scale)


func get_move_speed() -> float:
	return _move_speed


## Startet eine Aktion (siehe ACTIONS und Kurzformen oben). speed_scale > 1 spielt schneller.
## Läuft dieselbe Aktion schon, beginnt sie von vorn. Gibt false zurück, wenn tot oder unbekannt.
func play_action(action: StringName, speed_scale: float = 1.0) -> bool:
	if action in LOCOMOTION_NAMES:
		stop_action()
		return not _dead
	if action == &"attack":
		# AP2 übergibt Angriffe pro Sekunde: der Clip soll genau einen Angriff lang dauern.
		speed_scale = maxf(speed_scale, 0.01) * get_action_length(&"attack_1")
	action = ACTION_ALIASES.get(action, action)
	if _dead or not has_action(action):
		return false
	if action == &"death":
		play_death()
		return true
	if not _action.is_empty():
		action_finished.emit(_action)
	var clip := anim_tree.get_animation(action)
	_action = action
	_action_loops = clip.loop_mode != Animation.LOOP_NONE
	_action_left = clip.length / maxf(speed_scale, 0.01)
	anim_tree.set(ACTION_DONE_CONDITION, false)
	anim_tree.set(StringName("parameters/%s/speed/scale" % action), speed_scale)
	if _playback.get_current_node() == action:
		_playback.start(action, true)
	else:
		_playback.travel(action)
	return true


## Beendet die laufende Aktion (nötig für Schleifen wie Wirbelsturm oder Zielen).
func stop_action() -> void:
	if not _action.is_empty() and not _dead:
		_finish_action()


## Trefferreaktion mit Klang. Unterbricht die laufende Aktion.
func play_hit(speed_scale: float = 1.0) -> void:
	if play_action(&"hit", speed_scale):
		_play_sound(hit_sound)


func play_dodge(speed_scale: float = 1.0) -> void:
	play_action(&"dodge", speed_scale)


## Todesanimation; die Figur bleibt in der letzten Pose liegen, bis revive() kommt.
func play_death() -> void:
	if _dead:
		return
	if not _action.is_empty():
		action_finished.emit(_action)
	_dead = true
	_action = &""
	anim_tree.set(&"parameters/death/speed/scale", 1.0)
	_playback.travel(&"death")
	_play_sound(death_sound)


## Zurück ins Leben (Objekt-Pool, Wiederbelebung): sofort in die Fortbewegung.
func revive() -> void:
	_dead = false
	_action = &""
	anim_tree.set(ACTION_DONE_CONDITION, false)
	_playback.start(LOCOMOTION_STATE, true)


func is_dead() -> bool:
	return _dead


## true, solange eine Aktion läuft (Fortbewegung zählt nicht).
func is_busy() -> bool:
	return not _action.is_empty()


func get_current_action() -> StringName:
	return _action


func has_action(action: StringName) -> bool:
	return action in ACTIONS and anim_tree.has_animation(action)


## Länge einer Aktion in Sekunden bei normalem Tempo.
func get_action_length(action: StringName) -> float:
	return anim_tree.get_animation(action).length if has_action(action) else 0.0


## Zeitpunkt des ersten Ereignisses (zum Beispiel &"hit") in einer Animation, sonst -1.
## Hilft AP2/AP3, Angriffe ohne Bildschirm (headless) zeitgleich abzurechnen.
func get_event_time(anim: StringName, event: StringName) -> float:
	if not anim_tree.has_animation(anim):
		return -1.0
	var clip := anim_tree.get_animation(anim)
	for track in clip.get_track_count():
		if clip.track_get_type(track) != Animation.TYPE_METHOD:
			continue
		for key in clip.track_get_key_count(track):
			if clip.method_track_get_params(track, key)[0] == event:
				return clip.track_get_key_time(track, key)
	return -1.0


func get_skeleton() -> Skeleton3D:
	var root := get_node_or_null(^"Model")
	return root.get_node_or_null(^"%GeneralSkeleton") as Skeleton3D if root else null


## Wird von den Methodenspuren der Clips aufgerufen.
func _on_anim_event(event: StringName) -> void:
	match event:
		&"hit":
			hit_frame.emit()
		&"release":
			release_frame.emit()
		&"footstep":
			if _clock - _last_footstep < FOOTSTEP_MIN_INTERVAL:
				return
			_last_footstep = _clock
			footstep.emit()
			_play_sound(footstep_sound, -8.0)
	anim_event.emit(event)


func _finish_action() -> void:
	var finished := _action
	_action = &""
	anim_tree.set(ACTION_DONE_CONDITION, true)
	action_finished.emit(finished)


func _apply_looks() -> void:
	for part in hidden_parts:
		var node := model.find_child(part, true, false) as Node3D
		if node:
			node.visible = false
	if albedo_override == null and tint == Color.WHITE:
		return
	for mesh_instance in model.find_children("*", "MeshInstance3D", true, false):
		_recolor(mesh_instance as MeshInstance3D)


func _recolor(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return
	for surface in mesh_instance.mesh.get_surface_count():
		var source := mesh_instance.get_active_material(surface) as StandardMaterial3D
		if source == null:
			continue
		var material := source.duplicate() as StandardMaterial3D
		# Leuchtende Teile (Augen der Skelette) behalten ihre Farbe.
		if not material.emission_enabled:
			if albedo_override:
				material.albedo_texture = albedo_override
			material.albedo_color = material.albedo_color * tint
		mesh_instance.set_surface_override_material(surface, material)


func _attach_weapon(scene: PackedScene, bone: StringName, node_name: StringName) -> void:
	if scene == null:
		return
	var skeleton := get_skeleton()
	if skeleton == null or skeleton.find_bone(bone) < 0:
		push_warning("CharacterModel: Knochen %s fehlt" % bone)
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = node_name
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	attachment.add_child(scene.instantiate())


func _play_sound(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null or _audio == null:
		return
	_audio.stream = stream
	_audio.volume_db = volume_db
	_audio.play()
