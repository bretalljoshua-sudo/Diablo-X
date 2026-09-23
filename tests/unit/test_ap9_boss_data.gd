extends GutTest
## Daten des Gruftwächters (AP9) und Bausteine des Bossraums.

const BOSS_PATH := "res://data/encounters/crypt_warden.tres"

var def: BossDef


func before_all() -> void:
	def = load(BOSS_PATH) as BossDef


func test_boss_definition_is_complete() -> void:
	assert_not_null(def)
	assert_eq(def.display_name, "Der Gruftwächter")
	assert_not_null(def.enemy_type)
	assert_almost_eq(def.phase_two_threshold, 0.5, 0.001, "Phase 2 unter 50 %")
	assert_not_null(def.fire_affix, "Feuerflächen")
	assert_eq(def.fire_affix.kind, EliteAffix.Kind.BURNING)
	assert_not_null(def.chest_table, "Belohnungstruhe")
	assert_gte(def.enemy_type.attacks.size(), 3)
	assert_true(ResourceLoader.exists(def.enemy_type.model_path), "Modell vorhanden")


func test_phase_two_adds_summons_before_the_old_attacks() -> void:
	var phase_two := BossController.build_phase_two_type(def)
	assert_ne(phase_two, def.enemy_type, "eigene Kopie")
	assert_eq(
		phase_two.attacks.size(), def.enemy_type.attacks.size() + def.phase_two_attacks.size()
	)
	assert_eq(phase_two.attacks[0].kind, EnemyAttack.Kind.SUMMON, "Beschwören zuerst")
	assert_not_null(phase_two.attacks[0].summon_type)
	assert_eq(def.enemy_type.attacks.size(), 3, "Original bleibt unverändert")


func test_gate_turns_with_the_passage() -> void:
	var layout := LevelLayout.new()
	var floor_id := WorldTiles.Id.FLOOR
	layout.cells[Vector3i(0, 0, 0)] = floor_id
	layout.cells[Vector3i(0, 0, -1)] = floor_id
	layout.cells[Vector3i(0, 0, 1)] = floor_id
	layout.markers[&"boss_gate"] = WorldTiles.cell_center(Vector2i(0, 0), layout.cell_size)
	assert_almost_eq(BossGate.passage_angle(layout), 0.0, 0.001, "Durchgang entlang z")
	layout.cells.erase(Vector3i(0, 0, -1))
	layout.cells.erase(Vector3i(0, 0, 1))
	layout.cells[Vector3i(-1, 0, 0)] = floor_id
	layout.cells[Vector3i(1, 0, 0)] = floor_id
	assert_almost_eq(BossGate.passage_angle(layout), PI / 2.0, 0.001, "Durchgang entlang x")


func test_every_boss_level_has_the_markers_the_arena_needs() -> void:
	var layout := World.generate(4711, World.config_for_depth(World.BOSS_DEPTH))
	for marker: StringName in [&"boss_spawn", &"boss_chest", &"boss_gate", &"portal"]:
		assert_true(layout.markers.has(marker), "Marker %s" % marker)
