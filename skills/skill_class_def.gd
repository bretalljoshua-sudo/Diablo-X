class_name SkillClassDef
extends Resource
## Eine spielbare Klasse als Daten: ihre Skills, Startwerte und Stufen (data/skills/warrior.tres).

@export var id: StringName = &""
@export var display_name: String = ""
## Alle Skills der Klasse in Anzeigereihenfolge.
@export var skills: Array[SkillDef] = []

@export_group("Start")
## Skills, die zu Beginn schon gelernt sind (id → Rang).
@export var start_ranks: Dictionary[StringName, int] = {}
## Belegung der Skillleiste zu Beginn (Index = Platz, 0 = Linksklick), leer = frei.
@export var start_slots: Array[StringName] = []
## Freie Skillpunkte zu Beginn.
@export var start_points: int = 1

@export_group("Stufen")
@export var max_level: int = 10
## Skillpunkte je Stufenaufstieg.
@export var points_per_level: int = 2
## Erfahrung von Stufe n auf n + 1 (Index 0 = Stufe 1 auf 2). Fehlende Werte wachsen weiter.
@export var experience_per_level: Array[int] = []
## Werte, die jede Stufe über 1 dazugibt (feste Quelle &"level" am Spieler).
@export var stats_per_level: StatBlock
## Verteilte Punkte, ab denen eine Skill-Kategorie lernbar ist (Index = Enums.SkillCategory).
@export var category_unlock_points: Array[int] = [0, 2, 4, 6, 9]
## Schadenszuwachs je Rang über 1 (0.1 = +10 %), falls der Skill keinen eigenen
## Parameter damage_per_rank hat.
@export var damage_per_rank: float = 0.1


func find_skill(skill_id: StringName) -> SkillDef:
	for skill in skills:
		if skill != null and skill.id == skill_id:
			return skill
	return null


## Erfahrung, die von level auf level + 1 nötig ist (0 ab der Höchststufe).
func experience_for_level(level: int) -> int:
	if level >= max_level:
		return 0
	var index := level - 1
	if index < experience_per_level.size():
		return experience_per_level[index]
	var last := experience_per_level[-1] if not experience_per_level.is_empty() else 100
	return int(last * pow(1.25, index - experience_per_level.size() + 1))


func unlock_points_for(category: Enums.SkillCategory) -> int:
	return category_unlock_points[category] if category < category_unlock_points.size() else 0
