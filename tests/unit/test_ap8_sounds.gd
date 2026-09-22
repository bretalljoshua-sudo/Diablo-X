extends GutTest
## AP8: Klänge für Treffer, Schritte und Beute.

const ALL_SOUNDS: Array[AudioStream] = [
	GameSounds.FOOTSTEP,
	GameSounds.SWING,
	GameSounds.IMPACT,
	GameSounds.HURT,
	GameSounds.DEATH,
	GameSounds.BONE_BREAK,
	GameSounds.CAST,
	GameSounds.LOOT_DROP,
	GameSounds.LOOT_DROP_RARE,
	GameSounds.LOOT_DROP_LEGENDARY,
	GameSounds.LOOT_PICKUP,
	GameSounds.GOLD_PICKUP,
]


func test_every_sound_has_variants_that_load() -> void:
	for sound in ALL_SOUNDS:
		var randomizer := sound as AudioStreamRandomizer
		assert_not_null(randomizer, "%s ist ein AudioStreamRandomizer" % sound.resource_path)
		if randomizer == null:
			continue
		assert_gt(randomizer.streams_count, 0, sound.resource_path)
		for index in randomizer.streams_count:
			var stream := randomizer.get_stream(index)
			assert_not_null(stream, "%s Variante %d" % [sound.resource_path, index])
			if stream:
				assert_gt(stream.get_length(), 0.0)


func test_characters_have_sounds() -> void:
	for character: String in [
		"warrior", "skeleton_swarm", "ghoul", "skeleton_archer", "cultist_summoner"
	]:
		var model := (
			(load("res://assets/characters/%s.tscn" % character) as PackedScene).instantiate()
		)
		var figure := model as CharacterModel
		assert_not_null(figure.footstep_sound, "%s: Schritte" % character)
		assert_not_null(figure.attack_sound, "%s: Angriff" % character)
		assert_not_null(figure.hit_sound, "%s: Treffer" % character)
		assert_not_null(figure.death_sound, "%s: Tod" % character)
		model.free()


func test_footsteps_use_own_player() -> void:
	var model := (load("res://assets/characters/warrior.tscn") as PackedScene).instantiate()
	add_child_autofree(model)
	var steps := model.get_node(^"Steps") as AudioStreamPlayer3D
	var voice := model.get_node(^"Audio") as AudioStreamPlayer3D
	model.call(&"_on_anim_event", &"footstep")
	assert_eq(steps.stream, (model as CharacterModel).footstep_sound)
	assert_null(voice.stream, "Schritt schneidet keinen anderen Klang ab")


func test_play_at_creates_one_shot_player() -> void:
	var anchor := Node3D.new()
	add_child_autofree(anchor)
	var player := GameSounds.play_at(GameSounds.LOOT_DROP_RARE, Vector3(1, 0, 2), anchor)
	assert_not_null(player)
	if player:
		assert_true(player.is_inside_tree())
		assert_almost_eq(player.global_position, Vector3(1, 0, 2), Vector3.ONE * 0.001)
		assert_true(player.finished.is_connected(player.queue_free), "löscht sich selbst")
		player.queue_free()


func test_play_at_without_tree_is_safe() -> void:
	var loose := Node3D.new()
	assert_null(GameSounds.play_at(GameSounds.SWING, Vector3.ZERO, loose))
	loose.free()
