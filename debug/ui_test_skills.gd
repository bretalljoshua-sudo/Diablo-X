extends Node
## BEISPIELDATEN für die UI-Testszene (AP7): spielt die Rolle von AP5, bis das Skill-System steht.
## Sieben Krieger-Skills, Skillpunkte, Stufen, Skillleiste und Abklingzeiten, alles nur über den
## EventBus, genau wie AP5 es später tun soll (siehe docs/pakete/AP7.md).

## Verteilte Punkte, ab denen eine Kategorie frei ist.
const UNLOCK_POINTS: Dictionary[Enums.SkillCategory, int] = {
	Enums.SkillCategory.BASIC: 0,
	Enums.SkillCategory.CORE: 1,
	Enums.SkillCategory.DEFENSIVE: 3,
	Enums.SkillCategory.MOBILITY: 4,
	Enums.SkillCategory.ULTIMATE: 6,
}
const MAX_LEVEL := 10

var skills: Array[SkillDef] = []
var ranks: Dictionary[StringName, int] = {}
var points: int = 2
var level: int = 1
var experience: int = 0
var bar: Array[SkillDef] = []
var cooldowns: Dictionary[StringName, float] = {}
var fury: float = 0.0
var fury_max: float = 100.0


func _ready() -> void:
	bar.resize(SkillBar.SLOT_COUNT)
	_add(
		&"strike",
		"Hieb",
		Enums.SkillCategory.BASIC,
		0,
		10,
		0,
		1.0,
		"Schneller Schlag, erzeugt Wut."
	)
	_add(
		&"cleave",
		"Spaltschlag",
		Enums.SkillCategory.CORE,
		20,
		0,
		0,
		1.6,
		"Trifft alle Gegner im Bogen vor dir."
	)
	_add(
		&"whirlwind",
		"Wirbelsturm",
		Enums.SkillCategory.CORE,
		25,
		0,
		0,
		0.8,
		"Wirbelt durch Gegner, solange die Taste gehalten wird."
	)
	_add(
		&"war_cry",
		"Kriegsschrei",
		Enums.SkillCategory.DEFENSIVE,
		0,
		20,
		12,
		0.0,
		"Erhöht den Schaden von dir und senkt den erlittenen Schaden."
	)
	_add(
		&"leap",
		"Sprung",
		Enums.SkillCategory.MOBILITY,
		0,
		0,
		9,
		1.2,
		"Springt an einen Ort und erschüttert den Boden."
	)
	_add(
		&"charge",
		"Ansturm",
		Enums.SkillCategory.MOBILITY,
		0,
		0,
		10,
		1.0,
		"Stürmt vor und stößt Gegner zurück."
	)
	_add(
		&"ancients",
		"Zorn der Ahnen",
		Enums.SkillCategory.ULTIMATE,
		0,
		0,
		50,
		3.0,
		"Ruft drei Ahnen, die an deiner Seite kämpfen."
	)
	EventBus.skill_rank_up_requested.connect(rank_up)
	EventBus.skill_slot_assign_requested.connect(assign)
	send_all.call_deferred()


func _process(delta: float) -> void:
	for id: StringName in cooldowns.keys():
		cooldowns[id] = maxf(cooldowns[id] - delta, 0.0)


## Sendet alles, was die UI anzeigen soll.
func send_all() -> void:
	EventBus.skill_tree_changed.emit(make_state())
	for i in bar.size():
		EventBus.skill_slot_changed.emit(i, bar[i])
	EventBus.resource_changed.emit(fury, fury_max)
	EventBus.experience_changed.emit(experience, required_experience(), level)


func make_state() -> SkillTreeState:
	var state := SkillTreeState.new()
	state.skills = skills.duplicate()
	state.ranks = ranks.duplicate()
	state.points = points
	var spent := spent_points()
	for skill in skills:
		if skill.category == Enums.SkillCategory.ULTIMATE:
			state.max_ranks[skill.id] = 1
		var needed: int = UNLOCK_POINTS[skill.category]
		if spent >= needed:
			state.unlocked.append(skill.id)
		else:
			state.lock_reasons[skill.id] = (
				"Ab %d verteilten Punkten (%d verteilt)" % [needed, spent]
			)
	return state


func spent_points() -> int:
	var total := 0
	for id: StringName in ranks:
		total += ranks[id]
	return total


func rank_up(skill: SkillDef) -> void:
	var state := make_state()
	if not state.can_rank_up(skill):
		return
	ranks[skill.id] = state.get_rank(skill) + 1
	points -= 1
	# Neu gelernte Skills kommen auf den ersten freien Platz der Leiste.
	if ranks[skill.id] == 1 and not skill in bar:
		var free := bar.find(null)
		if free >= 0:
			assign(free, skill)
	EventBus.skill_tree_changed.emit(make_state())


func assign(slot: int, skill: SkillDef) -> void:
	if slot < 0 or slot >= bar.size() or ranks.get(skill.id, 0) <= 0:
		return
	var old := bar.find(skill)
	if old >= 0:
		bar[old] = null
		EventBus.skill_slot_changed.emit(old, null)
	bar[slot] = skill
	EventBus.skill_slot_changed.emit(slot, skill)


func gain_experience(amount: int) -> void:
	experience += amount
	while experience >= required_experience() and level < MAX_LEVEL:
		experience -= required_experience()
		level += 1
		points += 1
		EventBus.player_level_up.emit(level)
		EventBus.skill_tree_changed.emit(make_state())
	EventBus.experience_changed.emit(experience, required_experience(), level)


func required_experience() -> int:
	return 100 + (level - 1) * 60


## Setzt den Skill auf einem Platz ein (nur Anzeige: Wut, Abklingzeit, Aufleuchten).
func cast(slot: int, caster: Node3D) -> bool:
	var skill := bar[slot] if slot >= 0 and slot < bar.size() else null
	if skill == null or cooldowns.get(skill.id, 0.0) > 0.0 or fury < skill.cost:
		return false
	fury = clampf(fury - skill.cost + skill.generate, 0.0, fury_max)
	EventBus.resource_changed.emit(fury, fury_max)
	EventBus.skill_cast.emit(caster, skill, Vector3.ZERO)
	if skill.cooldown > 0.0:
		cooldowns[skill.id] = skill.cooldown
		EventBus.skill_cooldown_started.emit(skill, skill.cooldown)
	return true


func find(id: StringName) -> SkillDef:
	for skill in skills:
		if skill.id == id:
			return skill
	return null


func _add(
	id: StringName,
	display_name: String,
	category: Enums.SkillCategory,
	cost: float,
	generate: float,
	cooldown: float,
	multiplier: float,
	description: String
) -> void:
	var skill := SkillDef.new()
	skill.id = id
	skill.display_name = display_name
	skill.category = category
	skill.cost = cost
	skill.generate = generate
	skill.cooldown = cooldown
	skill.damage_multiplier = multiplier
	skill.description = description
	skill.tags = [id]
	skills.append(skill)
