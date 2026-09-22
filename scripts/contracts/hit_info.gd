class_name HitInfo
extends RefCounted
## Schadensanfrage: wer trifft wen womit. Wird an Combat.apply_damage() übergeben.

var source: Node3D
var target: Node3D
## Grundschaden vor Rüstung, Resistenzen und kritischen Treffern.
var base: float = 0.0
var type: Enums.DamageType = Enums.DamageType.PHYSICAL
## Auslösender Skill, null beim Standardangriff ohne SkillDef.
var skill: SkillDef
var can_crit: bool = true
## Rückstoß in Metern, 0 = keiner.
var knockback: float = 0.0


static func create(
	p_source: Node3D,
	p_target: Node3D,
	p_base: float,
	p_type: Enums.DamageType = Enums.DamageType.PHYSICAL
) -> HitInfo:
	var hit := HitInfo.new()
	hit.source = p_source
	hit.target = p_target
	hit.base = p_base
	hit.type = p_type
	return hit
