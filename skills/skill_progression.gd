class_name SkillProgression
extends RefCounted
## Erfahrung, Stufen, Skillpunkte und Ränge einer Klasse. Reine Logik ohne Szene.
##
## Regeln:
##   - Jeder Stufenaufstieg gibt SkillClassDef.points_per_level Punkte.
##   - Ein Punkt hebt einen Skill um einen Rang (höchstens max_rank, Parameter oder 5).
##   - Eine Kategorie ist lernbar, sobald genug Punkte verteilt sind (category_unlock_points).
##   - Ab SkillDef.upgrade_rank wirkt die Verbesserung des Skills.

var class_def: SkillClassDef
var level: int = 1
## Erfahrung innerhalb der aktuellen Stufe.
var experience: int = 0
var points: int = 0
var ranks: Dictionary[StringName, int] = {}


func _init(p_class_def: SkillClassDef = null) -> void:
	if p_class_def != null:
		setup(p_class_def)


func setup(p_class_def: SkillClassDef) -> void:
	class_def = p_class_def
	level = 1
	experience = 0
	points = class_def.start_points
	ranks = class_def.start_ranks.duplicate()


## Erfahrung dazu. Liefert die Zahl der Stufenaufstiege.
func add_experience(amount: int) -> int:
	if amount <= 0 or is_max_level():
		return 0
	experience += amount
	var gained := 0
	while not is_max_level() and experience >= required_experience():
		experience -= required_experience()
		_level_up()
		gained += 1
	if is_max_level():
		experience = 0
	return gained


## Setzt die Stufe direkt (Testszene, Speichern). Höhere Stufe gibt die Punkte dazu.
func set_level(new_level: int) -> int:
	new_level = clampi(new_level, 1, class_def.max_level)
	var gained := 0
	while level < new_level:
		_level_up()
		gained += 1
	experience = 0
	return gained


func is_max_level() -> bool:
	return level >= class_def.max_level


## Erfahrung bis zur nächsten Stufe (0 auf der Höchststufe).
func required_experience() -> int:
	return class_def.experience_for_level(level)


func get_rank(skill: SkillDef) -> int:
	return ranks.get(skill.id, 0) if skill != null else 0


func get_max_rank(skill: SkillDef) -> int:
	return int(skill.get_param(&"max_rank", SkillTreeState.DEFAULT_MAX_RANK))


func is_learned(skill: SkillDef) -> bool:
	return get_rank(skill) > 0


func is_upgraded(skill: SkillDef) -> bool:
	return skill != null and get_rank(skill) >= skill.upgrade_rank


func points_spent() -> int:
	var total := 0
	for rank: int in ranks.values():
		total += rank
	return total


func is_unlocked(skill: SkillDef) -> bool:
	return skill != null and points_spent() >= class_def.unlock_points_for(skill.category)


## Kurzer Grund, warum der Skill gesperrt ist, sonst "".
func lock_reason(skill: SkillDef) -> String:
	if is_unlocked(skill):
		return ""
	return "Ab %d verteilten Punkten" % class_def.unlock_points_for(skill.category)


func can_rank_up(skill: SkillDef) -> bool:
	return (
		skill != null
		and points > 0
		and is_unlocked(skill)
		and get_rank(skill) < get_max_rank(skill)
	)


func rank_up(skill: SkillDef) -> bool:
	if not can_rank_up(skill):
		return false
	points -= 1
	ranks[skill.id] = get_rank(skill) + 1
	return true


## Stand für die UI (EventBus.skill_tree_changed).
func build_state() -> SkillTreeState:
	var state := SkillTreeState.new()
	state.points = points
	for skill in class_def.skills:
		state.skills.append(skill)
		state.ranks[skill.id] = get_rank(skill)
		state.max_ranks[skill.id] = get_max_rank(skill)
		if is_unlocked(skill):
			state.unlocked.append(skill.id)
		else:
			state.lock_reasons[skill.id] = lock_reason(skill)
	return state


func to_dict() -> Dictionary:
	var saved_ranks := {}
	for id: StringName in ranks:
		saved_ranks[String(id)] = ranks[id]
	return {"level": level, "experience": experience, "points": points, "ranks": saved_ranks}


func from_dict(data: Dictionary) -> void:
	level = clampi(int(data.get("level", 1)), 1, class_def.max_level)
	experience = int(data.get("experience", 0))
	points = int(data.get("points", 0))
	ranks.clear()
	var saved: Dictionary = data.get("ranks", {})
	for id: String in saved:
		if class_def.find_skill(StringName(id)) != null:
			ranks[StringName(id)] = int(saved[id])


func _level_up() -> void:
	level += 1
	points += class_def.points_per_level
