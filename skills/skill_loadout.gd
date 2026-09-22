class_name SkillLoadout
extends RefCounted
## Skillleiste mit 6 Plätzen: 0 = Linksklick, 1 = Rechtsklick, 2 bis 5 = Tasten 1 bis 4.
## Der Linksklick-Platz nimmt nur Basis-Skills auf, weil Linksklick auch Laufen ist.

const SLOT_COUNT := 6
const PRIMARY_SLOT := 0
## Eingabe-Aktion je Platz (project.godot).
const ACTIONS: Array[StringName] = [
	&"primary_action", &"secondary_action", &"skill_1", &"skill_2", &"skill_3", &"skill_4"
]

var slots: Array[SkillDef] = []


func _init() -> void:
	slots.resize(SLOT_COUNT)


func get_skill(slot: int) -> SkillDef:
	return slots[slot] if is_valid_slot(slot) else null


static func is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT


static func action_for(slot: int) -> StringName:
	return ACTIONS[slot] if is_valid_slot(slot) else &""


## Platz des Skills oder -1.
func find_slot(skill: SkillDef) -> int:
	if skill == null:
		return -1
	for i in SLOT_COUNT:
		if slots[i] != null and slots[i].id == skill.id:
			return i
	return -1


## null leert den Platz. Linksklick nur für Basis-Skills.
static func can_hold(slot: int, skill: SkillDef) -> bool:
	if not is_valid_slot(slot):
		return false
	if skill == null or slot != PRIMARY_SLOT:
		return true
	return skill.category == Enums.SkillCategory.BASIC


## Legt den Skill auf den Platz. Liegt er schon woanders, tauschen die Plätze
## (wenn der verdrängte Skill auf den alten Platz passt, sonst wird der alte Platz frei).
## Liefert die geänderten Plätze, leer = nicht erlaubt oder keine Änderung.
func assign(slot: int, skill: SkillDef) -> Array[int]:
	var changed: Array[int] = []
	if not can_hold(slot, skill):
		return changed
	var previous := slots[slot]
	if previous == skill:
		return changed
	var old_slot := find_slot(skill)
	slots[slot] = skill
	changed.append(slot)
	if old_slot >= 0 and old_slot != slot:
		slots[old_slot] = previous if can_hold(old_slot, previous) else null
		changed.append(old_slot)
	return changed


## Erster freier Platz für einen neu gelernten Skill (Linksklick nur für Basis-Skills), sonst -1.
func first_free_slot(skill: SkillDef) -> int:
	for i in SLOT_COUNT:
		if slots[i] == null and can_hold(i, skill):
			return i
	return -1


func to_ids() -> Array[String]:
	var ids: Array[String] = []
	for skill in slots:
		ids.append(String(skill.id) if skill != null else "")
	return ids
