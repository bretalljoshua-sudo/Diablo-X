class_name SkillModifiers
extends RefCounted
## Was Rang, Verbesserung und Aspekte (AP4) an einem Skill-Einsatz ändern.
##
## Aspekte wirken über ihre Tags (AspectDef.skill_tags ∩ SkillDef.tags). Ausgewertet werden
## diese Parameter aus AspectDef.params, egal an welchem Aspekt sie stehen:
##   damage_bonus_percent     mehr Schaden (25 = +25 %)
##   resource_bonus_percent   mehr Wut-Aufbau
##   lifesteal_percent        heilt um diesen Anteil des verursachten Schadens
##   knockback                Rückstoß in Metern (ersetzt den Wert des Skills, wenn größer)
##   stun_duration            betäubt getroffene Gegner so viele Sekunden
##   burn_damage_percent,     setzt Gegner in Brand: pro Sekunde dieser Anteil des
##   burn_duration            Waffenschadens als Feuerschaden, so viele Sekunden
##   pull_radius,             zieht Gegner im Umkreis pro Sekunde so viele Meter heran
##   pull_strength            (kanalisierte Skills)
##   fire_damage_percent,     Feuerring um den Krieger: pro Sekunde dieser Anteil des
##   duration                 Waffenschadens, so viele Sekunden
##   extra_ancients           zusätzliche Einschläge bei Zorn der Ahnen

var rank: int = 1
## Verbesserung aktiv (Rang >= SkillDef.upgrade_rank).
var upgraded: bool = false
## Faktor auf den Schaden aus Rang und Aspekten.
var damage_factor: float = 1.0
## Faktor auf den Wut-Aufbau.
var resource_factor: float = 1.0
## Anteil des Schadens, der heilt (0.05 = 5 %).
var lifesteal: float = 0.0
## Rückstoß aus Aspekten in Metern (0 = keiner).
var knockback: float = 0.0
var stun_duration: float = 0.0
## Brennen: Anteil des Waffenschadens pro Sekunde (0.3 = 30 %).
var burn_ratio: float = 0.0
var burn_duration: float = 0.0
var pull_radius: float = 0.0
var pull_strength: float = 0.0
## Feuerring: Anteil des Waffenschadens pro Sekunde.
var fire_ring_ratio: float = 0.0
var fire_ring_duration: float = 0.0
var extra_ancients: int = 0
## Aspekte, die diesen Einsatz verändern.
var aspects: Array[AspectDef] = []


static func build(
	skill: SkillDef, p_rank: int, p_aspects: Array[AspectDef], default_damage_per_rank: float
) -> SkillModifiers:
	var mods := SkillModifiers.new()
	mods.rank = maxi(p_rank, 1)
	mods.upgraded = p_rank >= skill.upgrade_rank
	var per_rank := skill.get_param(&"damage_per_rank", default_damage_per_rank)
	var damage_bonus := 0.0
	var resource_bonus := 0.0
	for aspect in p_aspects:
		if aspect == null or not _matches(aspect, skill):
			continue
		mods.aspects.append(aspect)
		var p := aspect.params
		damage_bonus += p.get(&"damage_bonus_percent", 0.0) / 100.0
		resource_bonus += p.get(&"resource_bonus_percent", 0.0) / 100.0
		mods.lifesteal += p.get(&"lifesteal_percent", 0.0) / 100.0
		mods.knockback = maxf(mods.knockback, p.get(&"knockback", 0.0))
		mods.stun_duration = maxf(mods.stun_duration, p.get(&"stun_duration", 0.0))
		if p.has(&"burn_damage_percent"):
			mods.burn_ratio += p[&"burn_damage_percent"] / 100.0
			mods.burn_duration = maxf(mods.burn_duration, p.get(&"burn_duration", 3.0))
		if p.has(&"pull_strength"):
			mods.pull_radius = maxf(mods.pull_radius, p.get(&"pull_radius", 4.0))
			mods.pull_strength += p[&"pull_strength"]
		if p.has(&"fire_damage_percent"):
			mods.fire_ring_ratio += p[&"fire_damage_percent"] / 100.0
			mods.fire_ring_duration = maxf(mods.fire_ring_duration, p.get(&"duration", 4.0))
		mods.extra_ancients += int(p.get(&"extra_ancients", 0.0))
	mods.damage_factor = (1.0 + per_rank * (mods.rank - 1)) * (1.0 + damage_bonus)
	mods.resource_factor = 1.0 + resource_bonus
	return mods


func has_aspect(aspect_id: StringName) -> bool:
	for aspect in aspects:
		if aspect.id == aspect_id:
			return true
	return false


static func _matches(aspect: AspectDef, skill: SkillDef) -> bool:
	for tag in aspect.skill_tags:
		if tag in skill.tags:
			return true
	return false
