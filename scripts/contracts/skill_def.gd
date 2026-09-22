class_name SkillDef
extends Resource
## Beschreibung eines Skills als Daten. Das Verhalten baut AP5.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category: Enums.SkillCategory = Enums.SkillCategory.BASIC
## Ressourcenkosten (Wut), 0 = kostenlos.
@export var cost: float = 0.0
## Ressourcenaufbau pro Treffer oder Einsatz.
@export var generate: float = 0.0
@export var cooldown: float = 0.0
@export var targeting: Enums.Targeting = Enums.Targeting.MELEE_ARC
@export var attack_range: float = 2.0
@export var radius: float = 0.0
## Faktor auf den Waffenschaden, 1.0 = 100 %.
@export var damage_multiplier: float = 1.0
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
## Tags für Aspekte, zum Beispiel &"whirlwind", &"shout", &"physical".
@export var tags: Array[StringName] = []
## Name der Animation im AnimationTree (AP8).
@export var animation: StringName = &""
## Schlüssel für Vfx.spawn() (AP1).
@export var vfx_key: StringName = &""
