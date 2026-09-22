extends Node3D
## Testszene von AP5 (Skills und Krieger). Start: --scene=skills_test
##
## Alle sieben Skills sind gelernt (Rang 1) und liegen auf der Leiste, die Wut ist voll.
## Vor dem Krieger stehen Gruppen von Trainingspuppen (400 Leben, stehen nach 3 s wieder auf).
## Jede besiegte Puppe gibt 40 Erfahrung. Unten liegt die Oberfläche aus AP7 (Skillleiste, Wut,
## Erfahrung), K öffnet den Skillbaum.
##
## Tasten:
##   Linksklick  Hieb (Laufen und Angreifen)     Rechtsklick  Spaltschlag
##   1 Wirbelsturm (halten)   2 Kriegsschrei   3 Sprung / Ansturm   4 Zorn der Ahnen
##   F5 Stufe +1   F6 alle Skills Rang +1 (ab Rang 2 wirkt die Verbesserung)
##   F7 nächster Satz Aspekte   F8 Taste 3: Sprung ↔ Ansturm   F9 Wut voll, Abklingzeiten weg
##   R Puppen und Spieler zurücksetzen

## Erfahrung je besiegter Puppe.
const DUMMY_EXPERIENCE := 40
## Belegung der Leiste zu Beginn (Platz → Skill-id).
const START_BAR: Array[StringName] = [
	&"strike", &"cleave", &"whirlwind", &"war_cry", &"leap", &"ancients"
]
## Sätze von Aspekten, die F7 der Reihe nach anlegt (Aspekt-id oder Einzigartig-id).
const ASPECT_SETS: Array[Array] = [
	[],
	[&"aspect_maelstrom", &"aspect_tremor"],
	[&"aspect_bloodlust", &"aspect_flame_cry"],
	[&"aspect_stampede", &"aspect_cruelty"],
	[&"crown_of_ashes", &"wrath_of_ancients_axe"],
]
## Grundform je Platz für die Aspekt-Gegenstände.
const ASPECT_BASES: Array[StringName] = [
	&"iron_helm", &"chainmail", &"gauntlets", &"chain_leggings", &"iron_boots", &"bone_amulet"
]

const GAME_UI := preload("res://ui/game_ui.tscn")

var aspect_set_index: int = 0
## Oberfläche aus AP7 (HUD mit Skillleiste, Wut und Erfahrung, Skillbaum auf K).
var game_ui: GameUI

@onready var player: Player = $Player
@onready var nav_region: NavigationRegion3D = $NavRegion
@onready var rig: CameraRig = $CameraRig
@onready var status_label: Label = $Hud/Status
@onready var skills: SkillUser = SkillUser.find_on(player)


func _ready() -> void:
	nav_region.bake_navigation_mesh(false)
	rig.target = player
	rig.global_position = player.global_position
	EventBus.entity_died.connect(_on_entity_died)
	game_ui = GAME_UI.instantiate() as GameUI
	add_child(game_ui)
	if skills == null:
		push_warning("skills_test: Spieler hat kein Skill-System.")
		return
	for skill in skills.class_def.skills:
		skills.debug_set_rank(skill, maxi(skills.progression.get_rank(skill), 1))
	for slot in START_BAR.size():
		skills.assign_slot(slot, skills.class_def.find_skill(START_BAR[slot]))
	skills.fury.fill()


func _process(_delta: float) -> void:
	status_label.text = _status_text()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or skills == null:
		return
	match key.physical_keycode:
		KEY_F5:
			skills.set_level(skills.progression.level + 1)
		KEY_F6:
			for skill in skills.class_def.skills:
				skills.debug_set_rank(skill, skills.progression.get_rank(skill) + 1)
		KEY_F7:
			set_aspect_set((aspect_set_index + 1) % ASPECT_SETS.size())
		KEY_F8:
			var current := skills.bar.get_skill(4)
			var other := &"charge" if current != null and current.id == &"leap" else &"leap"
			skills.assign_slot(4, skills.class_def.find_skill(other))
		KEY_F9:
			skills.fury.fill()
			skills.clear_cooldowns()
		KEY_R:
			reset()
		_:
			return
	get_viewport().set_input_as_handled()


## Legt die Gegenstände eines Aspekt-Satzes an (vorher angelegte kommen weg).
func set_aspect_set(index: int) -> void:
	aspect_set_index = index
	var equipment := player.equipment
	for slot: Enums.Slot in [
		Enums.Slot.HELM,
		Enums.Slot.CHEST,
		Enums.Slot.GLOVES,
		Enums.Slot.PANTS,
		Enums.Slot.BOOTS,
		Enums.Slot.AMULET,
		Enums.Slot.WEAPON
	]:
		equipment.unequip(slot)
	var free_bases := ASPECT_BASES.duplicate()
	for id: StringName in ASPECT_SETS[index]:
		var item := make_aspect_item(id, free_bases)
		if item != null:
			equipment.equip(item)


## Gegenstand mit Aspekt oder einzigartiger Kraft. Nimmt für Aspekte die erste Grundform aus
## free_bases (und entfernt sie dort), damit jeder Aspekt einen eigenen Platz bekommt.
static func make_aspect_item(id: StringName, free_bases: Array[StringName]) -> ItemInstance:
	var db := ItemDatabase.get_default()
	var unique := db.get_unique(id)
	if unique != null:
		var generator := ItemGenerator.new(db)
		var unique_item := generator.create_unique(unique, 5, Rng.make(1))
		free_bases.erase(unique_item.base.id)
		return unique_item
	var aspect := db.get_aspect(id)
	if aspect == null or free_bases.is_empty():
		return null
	var item := ItemInstance.new()
	item.base = db.get_base(free_bases.pop_front())
	item.rarity = Enums.Rarity.LEGENDARY
	item.item_level = 5
	item.aspect = aspect
	item.display_name = "%s (%s)" % [item.base.display_name, aspect.display_name]
	return item


func get_dummies() -> Array[TrainingDummy]:
	var result: Array[TrainingDummy] = []
	for child in $Dummies.get_children():
		if child is TrainingDummy:
			result.append(child)
	return result


func reset() -> void:
	for dummy in get_dummies():
		dummy.health.revive(1.0)
		dummy.status_effects.clear()
	if player.is_dead():
		player.revive()
	else:
		player.health.reset_to_full()
	if skills != null:
		skills.fury.fill()
		skills.clear_cooldowns()


func _on_entity_died(entity: Node3D, killer: Node3D) -> void:
	if entity is TrainingDummy and killer == player and is_ancestor_of(entity):
		EventBus.experience_awarded.emit(DUMMY_EXPERIENCE, entity)


func _status_text() -> String:
	if skills == null:
		return "Kein Skill-System am Spieler."
	var p := skills.progression
	var lines: Array[String] = []
	var required := p.required_experience()
	var xp_text := "max" if required == 0 else "%d / %d" % [p.experience, required]
	lines.append("Stufe %d   Erfahrung %s   Skillpunkte %d" % [p.level, xp_text, p.points])
	lines.append(
		(
			"Leben %d / %d   Wut %d / %d"
			% [
				ceili(player.health.current),
				roundi(player.health.maximum),
				floori(skills.fury.current),
				roundi(skills.fury.maximum)
			]
		)
	)
	lines.append("")
	var keys := ["Links", "Rechts", "1", "2", "3", "4"]
	for slot in SkillLoadout.SLOT_COUNT:
		var skill := skills.bar.get_skill(slot)
		if skill == null:
			lines.append("%-6s  —" % keys[slot])
			continue
		var text := "%-6s  %s  Rang %d" % [keys[slot], skill.display_name, p.get_rank(skill)]
		if p.is_upgraded(skill):
			text += " (verbessert)"
		var left := skills.get_cooldown_left(skill)
		if left > 0.0:
			text += "   %.1f s" % left
		if skill.cost > 0.0:
			text += (
				"   %d Wut%s"
				% [skill.cost, "/s" if skill.targeting == Enums.Targeting.CHANNEL else ""]
			)
		lines.append(text)
	lines.append("")
	var aspects := player.equipment.get_aspects()
	var names: Array[String] = []
	for aspect in aspects:
		names.append(aspect.display_name)
	lines.append("Aspekte: %s" % (", ".join(names) if not names.is_empty() else "keine"))
	if skills.has_buff(ShoutCast.BUFF_KEY):
		lines.append("Kriegsschrei aktiv")
	lines.append("")
	lines.append("F5 Stufe +1  F6 Ränge +1  F7 Aspekte wechseln  F8 Taste 3: Sprung/Ansturm")
	lines.append("F9 Wut voll  R zurücksetzen")
	return "\n".join(lines)
