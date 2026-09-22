class_name EnemySpawnGroup
extends Resource
## Gegnergruppe, die zusammen erscheint und das Ziel gemeinsam bemerkt,
## zum Beispiel „Ghul mit Skeletten“.

@export var id: StringName = &""
@export var weight: float = 1.0
@export var members: Array[EnemySpawnMember] = []
## Abstand der Gruppenmitglieder voneinander beim Erscheinen.
@export var spacing: float = 1.6


## Würfelt die Typen der Mitglieder in Erscheinungsreihenfolge.
func roll_members(rng: RandomNumberGenerator) -> Array[EnemyType]:
	var result: Array[EnemyType] = []
	for member in members:
		var type := member.type as EnemyType
		if type == null:
			continue
		for i in rng.randi_range(member.count.x, maxi(member.count.x, member.count.y)):
			result.append(type)
	return result
