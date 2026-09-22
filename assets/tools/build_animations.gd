extends SceneTree
## Baut aus der importierten KayKit-Animationsbibliothek die fertigen Animationsdaten (AP8).
##
## Aufruf (nach einem Import):
##   godot --headless --path . -s res://assets/tools/build_animations.gd
##
## Erzeugt:
##   assets/animations/clips/<name>.res          aufbereitete Clips mit Methodenspuren
##   assets/animations/libraries/<figur>.tres     Bibliothek je Figur mit einheitlichen Namen
##   assets/animations/character_state_machine.tres  gemeinsamer Zustandsautomat
##
## Trefferzeitpunkte werden aus der Bewegung der Waffenhand berechnet: Spitze der
## Handgeschwindigkeit, danach der Moment, in dem die Hand abbremst (Aufprall).
## Schritte liegen dort, wo ein Fuß den Boden erreicht.

const SOURCE_LIBRARY := "res://assets/animations/kaykit_humanoid_anims.glb"
const PROBE_SCENE := "res://assets/characters/kaykit/barbarian.glb"
const CLIP_DIR := "res://assets/animations/clips/"
const LIBRARY_DIR := "res://assets/animations/libraries/"
const STATE_MACHINE_PATH := "res://assets/animations/character_state_machine.tres"
const SAMPLE_STEP := 1.0 / 60.0

## Methode, die die Methodenspuren am CharacterModel aufrufen.
const EVENT_METHOD := &"_on_anim_event"
## Pfad der Methodenspur relativ zum Wurzelknoten der Animation (dem Modell).
const EVENT_TRACK_PATH := NodePath("..")

## Einheitliche Namen, die jede Figur haben muss. Reihenfolge = Zustände im Automaten.
const LOCOMOTION: Array[StringName] = [&"idle", &"walk", &"run"]
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

## Clips, die in Schleife laufen.
const LOOPING: Array[String] = [
	"Idle",
	"Idle_Combat",
	"2H_Melee_Idle",
	"Unarmed_Idle",
	"Walking_A",
	"Walking_B",
	"Walking_C",
	"Walking_D_Skeletons",
	"Walking_Backwards",
	"Running_A",
	"Running_B",
	"Running_C",
	"2H_Melee_Attack_Spinning",
	"2H_Ranged_Aiming",
	"Blocking",
]

## Clips mit Trefferzeitpunkt (Ereignis "hit").
const HIT_CLIPS: Array[String] = [
	"1H_Melee_Attack_Chop",
	"1H_Melee_Attack_Jump_Chop",
	"1H_Melee_Attack_Slice_Diagonal",
	"1H_Melee_Attack_Slice_Horizontal",
	"1H_Melee_Attack_Stab",
	"2H_Melee_Attack_Chop",
	"2H_Melee_Attack_Slice",
	"2H_Melee_Attack_Spin",
	"2H_Melee_Attack_Spinning",
	"2H_Melee_Attack_Stab",
	"Unarmed_Melee_Attack_Punch_A",
	"Unarmed_Melee_Attack_Kick",
	"Block_Attack",
]

## Clips mit Auslösezeitpunkt in Sekunden (Ereignis "release": Pfeil, Zauber, Schrei).
## Von Hand gesetzt nach der Höhe und Geschwindigkeit der Hände (Hände oben, Stoß nach vorn),
## weil die Spitze der Handgeschwindigkeit hier oft das Ausholen trifft.
const RELEASE_TIMES := {
	"2H_Ranged_Shoot": 0.3,
	"Spellcast_Shoot": 0.17,
	"Spellcast_Long": 1.37,
	"Spellcast_Raise": 0.57,
	"Spellcast_Summon": 3.1,
	"Throw": 0.67,
	"Cheer": 0.4,
	"Taunt": 0.53,
}

## Zuordnung einheitlicher Name → KayKit-Clip je Figur.
const CHARACTERS := {
	"warrior":
	{
		"idle": "2H_Melee_Idle",
		"walk": "Walking_A",
		"run": "Running_A",
		"attack_1": "2H_Melee_Attack_Slice",
		"attack_2": "2H_Melee_Attack_Chop",
		"attack_3": "2H_Melee_Attack_Spinning",
		"attack_4": "1H_Melee_Attack_Jump_Chop",
		"cast": "Cheer",
		"hit": "Hit_A",
		"dodge": "Dodge_Forward",
		"spawn": "Taunt",
		"block": "Block",
		"interact": "PickUp",
		"death": "Death_A",
	},
	"skeleton_swarm":
	{
		"idle": "Idle_Combat",
		"walk": "Walking_D_Skeletons",
		"run": "Running_C",
		"attack_1": "1H_Melee_Attack_Chop",
		"attack_2": "1H_Melee_Attack_Slice_Diagonal",
		"attack_3": "1H_Melee_Attack_Stab",
		"attack_4": "1H_Melee_Attack_Jump_Chop",
		"cast": "Taunt",
		"hit": "Hit_B",
		"dodge": "Dodge_Backward",
		"spawn": "Spawn_Ground_Skeletons",
		"block": "Block",
		"interact": "Interact",
		"death": "Death_C_Skeletons",
	},
	"ghoul":
	{
		"idle": "2H_Melee_Idle",
		"walk": "Walking_C",
		"run": "Running_B",
		"attack_1": "2H_Melee_Attack_Chop",
		"attack_2": "2H_Melee_Attack_Slice",
		"attack_3": "2H_Melee_Attack_Spin",
		"attack_4": "Unarmed_Melee_Attack_Kick",
		"cast": "Taunt",
		"hit": "Hit_A",
		"dodge": "Dodge_Left",
		"spawn": "Spawn_Ground_Skeletons",
		"block": "Block",
		"interact": "Interact",
		"death": "Death_B",
	},
	"skeleton_archer":
	{
		"idle": "Idle",
		"walk": "Walking_B",
		"run": "Running_A",
		"attack_1": "2H_Ranged_Shoot",
		"attack_2": "1H_Melee_Attack_Stab",
		"attack_3": "2H_Ranged_Aiming",
		"attack_4": "2H_Ranged_Reload",
		"cast": "Taunt",
		"hit": "Hit_B",
		"dodge": "Dodge_Backward",
		"spawn": "Spawn_Ground_Skeletons",
		"block": "Block",
		"interact": "Interact",
		"death": "Death_C_Skeletons",
	},
	"cultist_summoner":
	{
		"idle": "Idle",
		"walk": "Walking_B",
		"run": "Running_B",
		"attack_1": "Spellcast_Shoot",
		"attack_2": "1H_Melee_Attack_Stab",
		"attack_3": "Spellcast_Long",
		"attack_4": "Spellcast_Raise",
		"cast": "Spellcast_Summon",
		"hit": "Hit_A",
		"dodge": "Dodge_Right",
		"spawn": "Spawn_Air",
		"block": "Block",
		"interact": "Interact",
		"death": "Death_A",
	},
}

var _skeleton: Skeleton3D
var _source: AnimationLibrary
var _clip_cache: Dictionary[String, Animation] = {}


func _init() -> void:
	var probe := (load(PROBE_SCENE) as PackedScene).instantiate()
	_skeleton = probe.find_child("GeneralSkeleton", true, false) as Skeleton3D
	_source = load(SOURCE_LIBRARY) as AnimationLibrary
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CLIP_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LIBRARY_DIR))
	var ok := true
	for character: String in CHARACTERS:
		ok = _build_library(character, CHARACTERS[character]) and ok
	ok = _save(_build_state_machine(), STATE_MACHINE_PATH) and ok
	probe.free()
	print("build_animations: %s" % ("fertig" if ok else "FEHLER"))
	quit(0 if ok else 1)


func _build_library(character: String, mapping: Dictionary) -> bool:
	var library := AnimationLibrary.new()
	for generic: StringName in LOCOMOTION + ACTIONS:
		var clip := _get_clip(String(mapping[String(generic)]))
		if clip == null:
			return false
		library.add_animation(generic, clip)
	return _save(library, LIBRARY_DIR + character + ".tres")


## Liefert den aufbereiteten Clip (einmal gespeichert, von allen Figuren geteilt).
func _get_clip(source_name: String) -> Animation:
	if _clip_cache.has(source_name):
		return _clip_cache[source_name]
	if not _source.has_animation(source_name):
		push_error("Clip fehlt in der Quelle: %s" % source_name)
		return null
	var clip := _source.get_animation(source_name).duplicate(true) as Animation
	clip.resource_name = source_name
	clip.loop_mode = Animation.LOOP_LINEAR if source_name in LOOPING else Animation.LOOP_NONE
	var events := _find_events(source_name, clip)
	if not events.is_empty():
		var track := clip.add_track(Animation.TYPE_METHOD)
		clip.track_set_path(track, EVENT_TRACK_PATH)
		for time: float in events:
			clip.track_insert_key(
				track, time, {"method": EVENT_METHOD, "args": [StringName(events[time])]}
			)
	var path := CLIP_DIR + source_name.to_snake_case() + ".res"
	if not _save(clip, path):
		return null
	var saved := load(path) as Animation
	_clip_cache[source_name] = saved
	return saved


## Zeitpunkte → Ereignisname für einen Clip.
func _find_events(source_name: String, clip: Animation) -> Dictionary:
	var events := {}
	if source_name in HIT_CLIPS:
		events[_impact_time(clip)] = &"hit"
	elif RELEASE_TIMES.has(source_name):
		events[minf(float(RELEASE_TIMES[source_name]), clip.length)] = &"release"
	elif source_name.begins_with("Walking") or source_name.begins_with("Running"):
		for time in _footstep_times(clip):
			events[time] = &"footstep"
	return events


## Aufprall: nach der Spitze der erste Moment, in dem die Hand auf die Hälfte abbremst.
func _impact_time(clip: Animation) -> float:
	var speeds := _hand_speeds(clip)
	var best := 0
	for i in speeds.size():
		if speeds[i] > speeds[best]:
			best = i
	var impact := best
	var limit := mini(speeds.size() - 1, best + int(0.25 / SAMPLE_STEP))
	while impact < limit and speeds[impact] > speeds[best] * 0.5:
		impact += 1
	return snappedf(impact * SAMPLE_STEP, 0.001)


func _hand_speeds(clip: Animation) -> PackedFloat32Array:
	var hand := _skeleton.find_bone("handslot.r")
	var speeds := PackedFloat32Array()
	var previous := Vector3.ZERO
	var time := 0.0
	while time <= clip.length:
		var position := _global_pose(clip, time)[hand].origin
		speeds.append(0.0 if time == 0.0 else (position - previous).length() / SAMPLE_STEP)
		previous = position
		time += SAMPLE_STEP
	return speeds


## Schritte: ein Fuß sinkt unter die Bodenschwelle (tiefster Punkt im Clip + 3 cm).
func _footstep_times(clip: Animation) -> Array[float]:
	var feet := [_skeleton.find_bone("LeftFoot"), _skeleton.find_bone("RightFoot")]
	var heights: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
	var time := 0.0
	while time < clip.length:
		var pose := _global_pose(clip, time)
		for f in 2:
			heights[f].append(pose[feet[f]].origin.y)
		time += SAMPLE_STEP
	var times: Array[float] = []
	for f in 2:
		var floor_y: float = Array(heights[f]).min() + 0.03
		var count := heights[f].size()
		for i in count:
			var before := heights[f][(i - 1 + count) % count]
			if heights[f][i] <= floor_y and before > floor_y:
				times.append(snappedf(i * SAMPLE_STEP, 0.001))
	times.sort()
	return times


## Globale Knochenlagen zum Zeitpunkt time, direkt aus den Spuren berechnet.
func _global_pose(clip: Animation, time: float) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for bone in _skeleton.get_bone_count():
		var rest := _skeleton.get_bone_rest(bone)
		var position := rest.origin
		var rotation := rest.basis.get_rotation_quaternion()
		var scale := rest.basis.get_scale()
		var path := NodePath("%GeneralSkeleton:" + _skeleton.get_bone_name(bone))
		var track := clip.find_track(path, Animation.TYPE_POSITION_3D)
		if track >= 0:
			position = clip.position_track_interpolate(track, time) * _skeleton.motion_scale
		track = clip.find_track(path, Animation.TYPE_ROTATION_3D)
		if track >= 0:
			rotation = clip.rotation_track_interpolate(track, time)
		track = clip.find_track(path, Animation.TYPE_SCALE_3D)
		if track >= 0:
			scale = clip.scale_track_interpolate(track, time)
		var local := Transform3D(Basis(rotation).scaled(scale), position)
		var parent := _skeleton.get_bone_parent(bone)
		result.append(local if parent < 0 else result[parent] * local)
	return result


## Gemeinsamer Zustandsautomat: "locomotion" (Stehen, Gehen, Laufen gemischt) und je eine
## Aktion. Jeder Zustand hat eine Zeitskala "speed", die das CharacterModel setzt.
func _build_state_machine() -> AnimationNodeStateMachine:
	var machine := AnimationNodeStateMachine.new()
	var locomotion := AnimationNodeBlendTree.new()
	var blend := AnimationNodeBlendSpace1D.new()
	blend.min_space = 0.0
	blend.max_space = 2.0
	blend.sync = true
	for i in LOCOMOTION.size():
		var node := AnimationNodeAnimation.new()
		node.animation = LOCOMOTION[i]
		blend.add_blend_point(node, float(i), -1, LOCOMOTION[i])
	locomotion.add_node(&"blend", blend, Vector2(0, 0))
	locomotion.add_node(&"speed", AnimationNodeTimeScale.new(), Vector2(200, 0))
	locomotion.connect_node(&"speed", 0, &"blend")
	locomotion.connect_node(&"output", 0, &"speed")
	machine.add_node(&"locomotion", locomotion, Vector2(0, 0))

	var start := AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	machine.add_transition(&"Start", &"locomotion", start)

	for i in ACTIONS.size():
		var action := ACTIONS[i]
		var tree := AnimationNodeBlendTree.new()
		var anim := AnimationNodeAnimation.new()
		anim.animation = action
		tree.add_node(&"anim", anim, Vector2(0, 0))
		tree.add_node(&"speed", AnimationNodeTimeScale.new(), Vector2(200, 0))
		tree.connect_node(&"speed", 0, &"anim")
		tree.connect_node(&"output", 0, &"speed")
		machine.add_node(action, tree, Vector2(300, i * 60 - 300))
		machine.add_transition(&"locomotion", action, _transition(false, 0.1))
		if action != &"death":
			# Zurück zur Fortbewegung, sobald CharacterModel die Bedingung "action_done"
			# setzt: am Ende einmaliger Clips oder bei stop_action() (Schleifen wie Wirbelsturm).
			var back := _transition(true, 0.15)
			back.advance_condition = &"action_done"
			machine.add_transition(action, &"locomotion", back)
	# Treffer, Ausweichen und Tod unterbrechen jede Aktion mit kurzer Überblendung.
	for action in ACTIONS:
		for interrupt: StringName in [&"hit", &"dodge", &"death"]:
			if action != interrupt and action != &"death":
				machine.add_transition(action, interrupt, _transition(false, 0.08))
	return machine


func _transition(auto: bool, xfade: float) -> AnimationNodeStateMachineTransition:
	var transition := AnimationNodeStateMachineTransition.new()
	transition.xfade_time = xfade
	transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	if auto:
		transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	else:
		transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
	return transition


func _save(resource: Resource, path: String) -> bool:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		push_error("Speichern fehlgeschlagen: %s (%s)" % [path, error_string(error)])
		return false
	resource.take_over_path(path)
	return true
