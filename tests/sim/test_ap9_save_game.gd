extends GutTest
## Spielstand (AP9): Figur, Stufe, Skills, Inventar, Ausrüstung, Gold und Fortschritt überstehen
## Speichern und Laden, auch über JSON und eine Datei.

const PLAYER_SCENE := "res://player/player.tscn"
const TEST_SAVE := "user://test_ap9_save.json"

var _previous_path: String


func before_each() -> void:
	_previous_path = SaveService.save_path
	SaveService.save_path = TEST_SAVE
	SaveService.delete_save()


func after_each() -> void:
	SaveService.delete_save()
	SaveService.save_path = _previous_path


func _spawn_player() -> Player:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.input_enabled = false
	add_child_autofree(player)
	await wait_physics_frames(2)
	return player


func _prepare(player: Player) -> void:
	var skills := SkillUser.find_on(player)
	skills.set_level(5)
	skills.rank_up(skills.class_def.find_skill(&"cleave"))
	skills.rank_up(skills.class_def.find_skill(&"war_cry"))
	var db := ItemDatabase.get_default()
	var gen := ItemGenerator.new(db)
	var rng := Rng.make(99)
	var sword := gen.create_item(db.get_base(&"crypt_blade"), Enums.Rarity.RARE, 5, rng)
	player.equipment.equip(sword)
	player.inventory.add_item(gen.create_item(sword.base, Enums.Rarity.MAGIC, 4, rng))
	player.inventory.add_gold(321)
	player.potions.charges = 1


func test_collect_and_apply_roundtrip_through_json() -> void:
	var source := await _spawn_player()
	_prepare(source)
	var progress := SaveGame.new_progress()
	progress["runs_completed"] = 2
	progress["boss_kills"] = 2
	var raw: Dictionary = JSON.parse_string(JSON.stringify(SaveGame.collect(source, progress)))
	assert_eq(int(raw["format"]), SaveGame.FORMAT)
	assert_eq(raw["game_version"], ProjectSettings.get_setting("application/config/version"))

	var target := await _spawn_player()
	SaveGame.apply(target, raw)
	var a := SkillUser.find_on(source)
	var b := SkillUser.find_on(target)
	assert_eq(b.progression.level, 5, "Stufe")
	assert_eq(b.progression.points, a.progression.points, "freie Skillpunkte")
	for id: StringName in [&"cleave", &"war_cry"]:
		var skill := b.class_def.find_skill(id)
		assert_eq(b.progression.get_rank(skill), a.progression.get_rank(skill), "Rang %s" % id)
	assert_eq(target.inventory.gold, 321, "Gold")
	assert_eq(target.inventory.get_items().size(), source.inventory.get_items().size(), "Inventar")
	var weapon := target.equipment.get_item(Enums.Slot.WEAPON)
	assert_not_null(weapon, "Waffe angelegt")
	if weapon != null:
		var original := source.equipment.get_item(Enums.Slot.WEAPON)
		assert_eq(weapon.uid, original.uid)
		assert_eq(weapon.get_stats().values, original.get_stats().values)
	assert_eq(target.potions.charges, target.potions.max_charges, "Tränke nach dem Laden voll")
	assert_eq(target.health.current, target.health.maximum, "Leben nach dem Laden voll")
	var loaded := SaveGame.progress_of(raw)
	assert_eq(int(loaded["runs_completed"]), 2)
	assert_eq(int(loaded["boss_kills"]), 2)


func test_write_and_read_file_with_version() -> void:
	var player := await _spawn_player()
	_prepare(player)
	assert_eq(SaveGame.write(player, SaveGame.new_progress()), OK)
	assert_true(SaveService.has_save())
	var file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	assert_eq(int(file["version"]), SaveService.SAVE_VERSION, "Versionsnummer von SaveService")
	var data := SaveGame.read()
	assert_eq(int((data["skills"] as Dictionary)["level"]), 5)
	assert_string_contains(SaveGame.summary(data), "Stufe 5")
	assert_string_contains(SaveGame.summary(data), "321 Gold")


func test_missing_or_newer_format_is_handled() -> void:
	assert_eq(SaveGame.read(), {}, "kein Spielstand")
	var progress := SaveGame.progress_of({"format": 1})
	assert_eq(int(progress["runs_completed"]), 0, "fehlender Fortschritt bekommt Startwerte")
	var migrated := SaveGame.migrate({"format": 99, "progress": {"deaths": 3}})
	assert_eq(int(migrated["format"]), SaveGame.FORMAT)
	assert_eq(int(SaveGame.progress_of(migrated)["deaths"]), 3)
