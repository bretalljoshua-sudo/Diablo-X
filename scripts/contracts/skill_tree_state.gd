class_name SkillTreeState
extends RefCounted
## Stand des Skillbaums für die UI. AP5 füllt ihn und sendet ihn über
## EventBus.skill_tree_changed; die UI zeigt ihn nur an.

const DEFAULT_MAX_RANK := 5

## Alle Skills der Klasse in Anzeigereihenfolge (die UI gruppiert nach SkillDef.category).
var skills: Array[SkillDef] = []
## Skill-id → gelernter Rang (fehlt = 0).
var ranks: Dictionary[StringName, int] = {}
## Skill-id → höchster Rang (fehlt = DEFAULT_MAX_RANK).
var max_ranks: Dictionary[StringName, int] = {}
## Skill-ids, deren Stufe freigeschaltet ist (zum Beispiel genug Punkte im Baum verteilt).
var unlocked: Array[StringName] = []
## Freie Skillpunkte.
var points: int = 0
## Skill-id → kurzer Grund, warum er gesperrt ist („Ab 2 verteilten Punkten“).
var lock_reasons: Dictionary[StringName, String] = {}


func get_rank(skill: SkillDef) -> int:
	return ranks.get(skill.id, 0) if skill != null else 0


func get_max_rank(skill: SkillDef) -> int:
	return max_ranks.get(skill.id, DEFAULT_MAX_RANK) if skill != null else 0


func is_unlocked(skill: SkillDef) -> bool:
	return skill != null and skill.id in unlocked


func can_rank_up(skill: SkillDef) -> bool:
	return points > 0 and is_unlocked(skill) and get_rank(skill) < get_max_rank(skill)


func find_skill(id: StringName) -> SkillDef:
	for skill in skills:
		if skill.id == id:
			return skill
	return null
