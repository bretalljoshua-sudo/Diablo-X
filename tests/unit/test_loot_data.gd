extends GutTest
## Prüft die Beute-Inhalte in data/ (AP4): Umfang laut Plan und Stimmigkeit der Daten.

var db: ItemDatabase


func before_all() -> void:
	db = ItemDatabase.load_from_data()


func test_scope_matches_plan() -> void:
	assert_between(db.affixes.size(), 22, 30, "rund 25 Affixe")
	assert_eq(db.aspects.size(), 6, "6 legendäre Aspekte")
	assert_eq(db.uniques.size(), 2, "2 einzigartige Gegenstände")
	assert_not_null(db.rarity)
	assert_not_null(db.name_parts)
	assert_not_null(db.skill_tags)


func test_every_slot_has_a_level_1_base() -> void:
	for slot: Enums.Slot in Enums.Slot.values():
		var found := false
		for base in db.bases:
			if ItemDatabase.slot_matches(base.slot, slot) and base.min_level == 1:
				found = true
		assert_true(found, "Grundform auf Stufe 1 für %s" % ItemText.slot_name(slot))


func test_ids_are_unique() -> void:
	var ids: Array[StringName] = []
	for base in db.bases:
		ids.append(base.id)
	for affix in db.affixes:
		ids.append(affix.id)
	for aspect in db.aspects:
		ids.append(aspect.id)
	for def in db.uniques:
		ids.append(def.id)
		ids.append(def.power.id)
	for id in ids:
		assert_ne(id, &"", "keine leere id")
		assert_eq(ids.count(id), 1, "id %s nur einmal" % id)


func test_affixes_are_sane() -> void:
	for affix in db.affixes:
		assert_lt(affix.min_value, affix.max_value, "%s: min < max" % affix.id)
		assert_gt(affix.weight, 0.0)
		assert_true(affix.text.contains("{value}"), "%s: Text mit {value}" % affix.id)


func test_every_base_can_roll_enough_affixes() -> void:
	for base in db.bases:
		var stats: Array[Enums.Stat] = []
		for affix in db.affixes_for(base):
			if not affix.stat in stats:
				stats.append(affix.stat)
		assert_gte(stats.size(), 4, "%s braucht mindestens 4 Stat-Arten" % base.id)


func test_aspect_tags_are_in_catalog() -> void:
	var powers: Array[AspectDef] = db.aspects.duplicate()
	for def in db.uniques:
		powers.append(def.power)
	for aspect in powers:
		assert_false(aspect.skill_tags.is_empty(), "%s wirkt auf Skill-Tags" % aspect.id)
		for tag in aspect.skill_tags:
			assert_true(db.skill_tags.has_tag(tag), "%s: Tag %s im Katalog" % [aspect.id, tag])
		# Jeder Platzhalter in der Beschreibung ist ein Parameter.
		assert_false(ItemText.aspect_text(aspect).contains("{"), "%s: Platzhalter" % aspect.id)


func test_uniques_use_allowed_affixes() -> void:
	for def in db.uniques:
		assert_not_null(def.base)
		assert_false(def.affixes.is_empty())
		for roll in def.affixes:
			assert_true(roll.affix in db.affixes_for(def.base), "%s: %s" % [def.id, roll.affix.id])


func test_loot_tables_load() -> void:
	for table_name: StringName in [&"normal", &"elite", &"boss", &"chest"]:
		var table := Loot.get_table(table_name)
		assert_not_null(table, String(table_name))
		assert_false(table.entries.is_empty())
		assert_gt(table.gold.y, 0)


func test_ground_item_uses_loot_layer() -> void:
	var node := (load(GroundItem.SCENE_PATH) as PackedScene).instantiate() as GroundItem
	assert_eq(node.collision_layer, PhysicsLayers.LOOT)
	node.free()
