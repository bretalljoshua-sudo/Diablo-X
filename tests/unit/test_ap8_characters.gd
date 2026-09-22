extends GutTest
## AP8: Figuren-Szenen, gemeinsames Skelett, Animationsbibliotheken und Trefferzeitpunkte.

const CHARACTERS: Array[String] = [
	"warrior", "skeleton_swarm", "ghoul", "skeleton_archer", "cultist_summoner"
]
const LOCOMOTION: Array[StringName] = [&"idle", &"walk", &"run"]
## Knochen des gemeinsamen Skeletts (Godot-Humanoid-Namen nach dem Retargeting).
const HUMANOID_BONES: Array[StringName] = [
	&"Hips",
	&"Spine",
	&"Chest",
	&"Head",
	&"LeftUpperArm",
	&"LeftLowerArm",
	&"LeftHand",
	&"RightUpperArm",
	&"RightLowerArm",
	&"RightHand",
	&"LeftUpperLeg",
	&"LeftLowerLeg",
	&"LeftFoot",
	&"RightUpperLeg",
	&"RightLowerLeg",
	&"RightFoot",
]
## Angriff, der bei jeder Figur einen Treffer oder ein Auslösen haben muss.
const MAIN_ATTACK_EVENT := {
	"warrior": &"hit",
	"skeleton_swarm": &"hit",
	"ghoul": &"hit",
	"skeleton_archer": &"release",
	"cultist_summoner": &"release",
}


func _spawn(character: String) -> CharacterModel:
	var scene := load("res://assets/characters/%s.tscn" % character) as PackedScene
	assert_not_null(scene, "%s.tscn lädt" % character)
	var model := scene.instantiate() as CharacterModel
	assert_not_null(model, "%s ist ein CharacterModel" % character)
	add_child_autofree(model)
	return model


func test_all_characters_share_humanoid_skeleton() -> void:
	for character in CHARACTERS:
		var model := _spawn(character)
		var skeleton := model.get_skeleton()
		assert_not_null(skeleton, "%s hat %%GeneralSkeleton" % character)
		if skeleton == null:
			continue
		for bone in HUMANOID_BONES:
			assert_gt(skeleton.find_bone(bone), -1, "%s: Knochen %s" % [character, bone])
		assert_gt(skeleton.find_bone(&"handslot.r"), -1, "%s: Waffenknochen" % character)


func test_all_characters_have_every_animation() -> void:
	for character in CHARACTERS:
		var model := _spawn(character)
		for anim in LOCOMOTION + CharacterModel.ACTIONS:
			assert_true(model.anim_tree.has_animation(anim), "%s: Animation %s" % [character, anim])


func test_animation_tracks_reach_the_skeleton() -> void:
	# Jede Spur zeigt auf %GeneralSkeleton; so passen Clips auf jedes Modell mit diesem Skelett.
	var model := _spawn("warrior")
	var clip := model.anim_tree.get_animation(&"attack_1")
	var bone_tracks := 0
	for track in clip.get_track_count():
		if clip.track_get_type(track) == Animation.TYPE_METHOD:
			continue
		var path := String(clip.track_get_path(track))
		assert_true(path.begins_with("%GeneralSkeleton:"), "Spur %s" % path)
		bone_tracks += 1
	assert_gt(bone_tracks, 20)


func test_main_attacks_have_event_inside_clip() -> void:
	for character: String in MAIN_ATTACK_EVENT:
		var model := _spawn(character)
		var event: StringName = MAIN_ATTACK_EVENT[character]
		var time := model.get_event_time(&"attack_1", event)
		assert_gt(time, 0.0, "%s: %s in attack_1" % [character, event])
		assert_lt(time, model.get_action_length(&"attack_1"), "%s: Zeitpunkt im Clip" % character)


func test_melee_attacks_of_warrior_all_hit() -> void:
	var model := _spawn("warrior")
	for action: StringName in [&"attack_1", &"attack_2", &"attack_3", &"attack_4"]:
		assert_gt(model.get_event_time(action, &"hit"), 0.0, "Krieger %s hat Treffer" % action)


func test_walk_and_run_have_footsteps() -> void:
	for character in CHARACTERS:
		var model := _spawn(character)
		for anim: StringName in [&"walk", &"run"]:
			assert_gt(model.get_event_time(anim, &"footstep"), -1.0, "%s: %s" % [character, anim])


func test_weapons_are_attached_to_hand() -> void:
	for character: String in ["skeleton_swarm", "ghoul", "skeleton_archer", "cultist_summoner"]:
		var model := _spawn(character)
		var attachment := model.get_skeleton().get_node_or_null(^"WeaponRight") as BoneAttachment3D
		assert_not_null(attachment, "%s trägt eine Waffe" % character)
		if attachment:
			assert_eq(attachment.bone_name, "handslot.r")


func test_hidden_parts_are_hidden() -> void:
	var model := _spawn("warrior")
	var shield := model.model.find_child("Barbarian_Round_Shield", true, false) as Node3D
	assert_not_null(shield)
	if shield:
		assert_false(shield.visible, "Schild ausgeblendet, Krieger kämpft zweihändig")
	var axe := model.model.find_child("2H_Axe", true, false) as Node3D
	assert_true(axe != null and axe.visible, "Zweihandaxt sichtbar")


func test_models_face_negative_z() -> void:
	# Godot-Konvention: vorn ist -Z. Die KayKit-Modelle schauen nach +Z und sind gedreht.
	for character in CHARACTERS:
		var model := _spawn(character)
		var forward := model.model.transform.basis.z.normalized()
		assert_almost_eq(forward.z, -1.0, 0.01, "%s schaut nach -Z" % character)


func test_move_velocity_blends_locomotion() -> void:
	var model := _spawn("warrior")
	var path := &"parameters/locomotion/blend/blend_position"
	var scale_path := &"parameters/locomotion/speed/scale"
	model.set_move_velocity(0.0)
	assert_almost_eq(float(model.anim_tree.get(path)), 0.0, 0.001)
	model.set_move_velocity(model.walk_speed)
	assert_almost_eq(float(model.anim_tree.get(path)), 1.0, 0.001)
	model.set_move_velocity(model.run_speed * 1.5)
	assert_almost_eq(float(model.anim_tree.get(path)), 2.0, 0.001)
	assert_almost_eq(float(model.anim_tree.get(scale_path)), 1.5, 0.001)
	model.set_move_velocity(model.run_speed * 10.0)
	assert_almost_eq(
		float(model.anim_tree.get(scale_path)), CharacterModel.MAX_LOCOMOTION_SCALE, 0.001
	)


func test_ap2_interface_move_ratio() -> void:
	# player.gd ruft set_move_speed(anteil) mit 0 bis 1 der Höchstgeschwindigkeit auf.
	var model := _spawn("warrior")
	model.set_move_speed(1.0)
	assert_almost_eq(model.get_move_speed(), model.reference_max_speed, 0.001)
	model.set_move_speed(0.0)
	assert_almost_eq(model.get_move_speed(), 0.0, 0.001)


func test_ap2_interface_action_aliases() -> void:
	var model := _spawn("warrior")
	await wait_process_frames(1)
	assert_true(model.play_action(&"attack", 1.5), "attack mit Angriffen pro Sekunde")
	assert_eq(model.get_current_action(), &"attack_1")
	var scale := float(model.anim_tree.get(&"parameters/attack_1/speed/scale"))
	assert_almost_eq(model.get_action_length(&"attack_1") / scale, 1.0 / 1.5, 0.001)
	assert_true(model.play_action(&"run", 1.0), "run beendet die Aktion")
	assert_false(model.is_busy())
	assert_true(model.play_action(&"stunned", 1.0))
	assert_eq(model.get_current_action(), &"hit")
	assert_true(model.play_action(&"dodge", 1.0))
	assert_true(model.play_action(&"death", 1.0))
	assert_true(model.is_dead())


func test_unknown_action_is_rejected() -> void:
	var model := _spawn("ghoul")
	assert_false(model.play_action(&"fly"))
	assert_false(model.is_busy())
