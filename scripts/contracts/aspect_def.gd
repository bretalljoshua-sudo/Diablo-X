class_name AspectDef
extends Resource
## Legendärer Aspekt, der Skills verändert. Wirkt über Skill-Tags (siehe SkillDef.tags).

@export var id: StringName = &""
@export var display_name: String = ""
## Beschreibung mit Platzhaltern für params, zum Beispiel "Wirbelsturm zieht Gegner {radius} m an".
@export_multiline var description: String = ""
## Skills mit mindestens einem dieser Tags werden verändert.
@export var skill_tags: Array[StringName] = []
## Freie Zahlenwerte, die das Skill-System (AP5) auswertet.
@export var params: Dictionary[StringName, float] = {}
