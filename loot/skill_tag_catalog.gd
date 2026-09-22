class_name SkillTagCatalog
extends Resource
## Alle Skill-Tags, auf die Aspekte und einzigartige Kräfte wirken können.
## Daten: data/aspects/skill_tags.tres. AP5 vergibt diese Tags in SkillDef.tags.

## Tag → Beschreibung, wofür er steht.
@export var tags: Dictionary[StringName, String] = {}


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
