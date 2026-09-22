class_name SkillUser
extends Node
## Skill-System des Spielers (AP5): Skillleiste, Wut, Abklingzeiten, Erfahrung, Stufen und
## Skillpunkte. Hängt als Kind an der Spielerfigur (Player lädt skills/warrior_skills.tscn).
##
## Eingaben (project.godot): Linksklick bleibt Laufen und Angreifen der Spielerfigur, der
## Treffer ist aber der Skill auf Platz 0 (Hieb). Rechtsklick und 1 bis 4 setzen die Skills
## der Plätze 1 bis 5 zur Maus ein; Halten wiederholt, kanalisierte Skills laufen, solange
## die Taste gehalten wird.
##
## Signale an andere Pakete (alle über EventBus, Einzelheiten in docs/pakete/AP5.md):
##   skill_cast, skill_cast_failed, skill_cooldown_started, skill_slot_changed,
##   skill_tree_changed, resource_changed, experience_changed, player_level_up
## Hört auf: experience_awarded, skill_rank_up_requested, skill_slot_assign_requested.

signal cast_started(skill: SkillDef, slot: int)
signal cast_finished(skill: SkillDef)

const DEFAULT_CLASS_PATH := "res://data/skills/warrior.tres"
## Feste Quelle am Spieler für Werte aus der Stufe.
const LEVEL_SOURCE := &"level"
## Abklingzeitverringerung höchstens so viel.
const MAX_COOLDOWN_REDUCTION := 0.75
## Verhalten, wenn SkillDef.behavior leer ist.
const DEFAULT_BEHAVIORS: Dictionary[Enums.Targeting, StringName] = {
	Enums.Targeting.MELEE_ARC: &"melee",
	Enums.Targeting.CHANNEL: &"whirlwind",
	Enums.Targeting.SELF_AOE: &"shout",
	Enums.Targeting.GROUND_TARGET: &"leap",
	Enums.Targeting.DASH: &"charge",
}

@export var class_def: SkillClassDef

var player: Player
var progression: SkillProgression
var bar: SkillLoadout
## Wut.
var fury: ResourcePool
## Laufender Einsatz, der die Figur sperrt, oder null.
var active_cast: SkillCast
## Einsätze, die nebenher laufen (Feuerring, Einschläge der Ahnen).
var background_casts: Array[SkillCast] = []

var _cooldowns: Dictionary[StringName, float] = {}
var _buffs: Dictionary[StringName, float] = {}
var _combo: Dictionary[StringName, int] = {}
var _equipment: Equipment
## Plätze, deren Taste hier gedrückt wurde (nicht von der UI verschluckt), für das Halten.
var _pressed_slots: Dictionary[int, bool] = {}


## Das Skill-System an einer Figur (oder die Figur selbst), sonst null.
static func find_on(entity: Node) -> SkillUser:
	if entity == null or not is_instance_valid(entity):
		return null
	if entity is SkillUser:
		return entity
	for child in entity.get_children():
		if child is SkillUser:
			return child
	return null


func _ready() -> void:
	player = get_parent() as Player
	if player == null:
		push_warning("SkillUser: Elternknoten ist keine Spielerfigur.")
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	if class_def == null:
		class_def = load(DEFAULT_CLASS_PATH) as SkillClassDef
	progression = SkillProgression.new(class_def)
	bar = SkillLoadout.new()
	for i in mini(class_def.start_slots.size(), SkillLoadout.SLOT_COUNT):
		var skill := class_def.find_skill(class_def.start_slots[i])
		if skill != null and SkillLoadout.can_hold(i, skill):
			bar.slots[i] = skill
	fury = ResourcePool.new()
	fury.changed.connect(_on_fury_changed)
	_equipment = Equipment.find_on(player)
	player.stats.stats_changed.connect(_update_fury_maximum)
	_update_fury_maximum()
	player.state_changed.connect(_on_player_state_changed)
	if player.model != null and player.model.has_signal(&"hit_frame"):
		player.model.connect(&"hit_frame", _on_model_hit_frame)
	EventBus.experience_awarded.connect(_on_experience_awarded)
	EventBus.skill_rank_up_requested.connect(_on_rank_up_requested)
	EventBus.skill_slot_assign_requested.connect(_on_slot_assign_requested)
	_apply_level_stats()
	_update_basic_attack()
	broadcast_state.call_deferred()


func _physics_process(delta: float) -> void:
	_tick_cooldowns(delta)
	_tick_buffs(delta)
	var regen := Stats.get_stat(player, Enums.Stat.RESOURCE_REGEN)
	if regen > 0.0:
		fury.gain(regen * delta)
	if player.input_enabled:
		_process_held_input()
	if active_cast != null:
		active_cast.physics(delta)
		if active_cast != null and active_cast.finished:
			_end_active_cast()
	for cast in background_casts.duplicate():
		if not cast.finished:
			cast.physics(delta)
		if cast.finished:
			background_casts.erase(cast)


func _unhandled_input(event: InputEvent) -> void:
	if not player.input_enabled:
		return
	for slot in range(1, SkillLoadout.SLOT_COUNT):
		var action := SkillLoadout.action_for(slot)
		if event.is_action_pressed(action):
			_pressed_slots[slot] = true
			cast_slot(slot)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_released(action):
			_pressed_slots.erase(slot)
			if active_cast != null and active_cast.slot == slot:
				active_cast.release()
			return


# --- Befehle -------------------------------------------------------------------------------


## Setzt den Skill eines Platzes ein. point = Vector3.INF: zur Maus (bei Eingabe), sonst
## in Blickrichtung. silent = keine skill_cast_failed-Meldung (Wiederholen beim Halten).
func cast_slot(
	slot: int, point: Vector3 = Vector3.INF, target: Node3D = null, silent: bool = false
) -> bool:
	var skill := bar.get_skill(slot)
	if skill == null:
		return false
	if point == Vector3.INF and player.input_enabled:
		target = player.hovered_target
		point = target.global_position if target != null else player.mouse_ground_point()
	return try_cast(skill, point, target, slot, silent)


## Setzt einen Skill ein, auch ohne Platz (Bots, Tests). Liefert false mit
## EventBus.skill_cast_failed, wenn er nicht gelernt, nicht bereit oder zu teuer ist.
func try_cast(
	skill: SkillDef,
	point: Vector3 = Vector3.INF,
	target: Node3D = null,
	slot: int = -1,
	silent: bool = false
) -> bool:
	var reason := check_cast(skill)
	if reason != &"":
		if not silent:
			EventBus.skill_cast_failed.emit(skill, reason)
		return false
	var cast := create_cast(skill, point, target)
	cast.slot = slot
	if cast.locks_player() and not player.begin_cast():
		if not silent:
			EventBus.skill_cast_failed.emit(skill, &"busy")
		return false
	if not cast.is_channeled():
		fury.spend(skill.cost)
	_start_cooldown(skill)
	if cast.locks_player():
		active_cast = cast
	else:
		background_casts.append(cast)
	var cast_point := point if point != Vector3.INF else player.global_position
	EventBus.skill_cast.emit(player, skill, cast_point)
	cast_started.emit(skill, slot)
	cast.start()
	if cast == active_cast and cast.finished:
		_end_active_cast()
	return true


## Beendet einen kanalisierten Skill (wie Taste loslassen).
func release_active() -> void:
	if active_cast != null:
		active_cast.release()


## Leer = einsetzbar, sonst der Grund wie bei EventBus.skill_cast_failed.
func check_cast(skill: SkillDef) -> StringName:
	if skill == null or not progression.is_learned(skill):
		return &"not_learned"
	if not player.can_act() or player.state == Player.State.DODGING or active_cast != null:
		return &"busy"
	if get_cooldown_left(skill) > 0.0:
		return &"cooldown"
	var cost := skill.cost
	if skill.targeting == Enums.Targeting.CHANNEL:
		cost *= skill.get_param(&"tick_interval", 0.25)
	if not fury.can_afford(cost):
		return &"resource"
	return &""


func create_cast(skill: SkillDef, point: Vector3, target: Node3D = null) -> SkillCast:
	var behavior := skill.behavior
	if behavior == &"":
		behavior = DEFAULT_BEHAVIORS.get(skill.targeting, &"melee")
	var cast := new_cast(behavior)
	return cast.setup(self, skill, get_modifiers(skill), point, target)


## Verhalten je SkillDef.behavior (unbekannt = Nahkampf).
static func new_cast(behavior: StringName) -> SkillCast:
	match behavior:
		&"whirlwind":
			return WhirlwindCast.new()
		&"shout":
			return ShoutCast.new()
		&"leap":
			return LeapCast.new()
		&"charge":
			return ChargeCast.new()
		&"ancients":
			return AncientsCast.new()
	return MeleeCast.new()


## Rang, Verbesserung und Aspekte für einen Skill, so wie sie gerade gelten.
func get_modifiers(skill: SkillDef) -> SkillModifiers:
	var aspects: Array[AspectDef] = []
	if is_instance_valid(_equipment):
		aspects = _equipment.get_aspects_for_tags(skill.tags)
	return SkillModifiers.build(
		skill, progression.get_rank(skill), aspects, class_def.damage_per_rank
	)


## Einen Rang mehr (kostet einen Punkt). Ein neu gelernter Skill kommt auf den ersten freien
## Platz der Leiste.
func rank_up(skill: SkillDef) -> bool:
	skill = _own_skill(skill)
	var was_learned := progression.is_learned(skill)
	if not progression.rank_up(skill):
		return false
	if not was_learned:
		_place_new_skill(skill)
	EventBus.skill_tree_changed.emit(progression.build_state())
	return true


## Legt einen gelernten Skill auf einen Platz (null leert ihn). Linksklick nur Basis-Skills.
func assign_slot(slot: int, skill: SkillDef) -> bool:
	skill = _own_skill(skill)
	if skill != null and not progression.is_learned(skill):
		return false
	var changed := bar.assign(slot, skill)
	for changed_slot in changed:
		EventBus.skill_slot_changed.emit(changed_slot, bar.get_skill(changed_slot))
	_update_basic_attack()
	return not changed.is_empty()


func add_experience(amount: int) -> void:
	var before := progression.level
	var gained := progression.add_experience(amount)
	if gained > 0:
		_on_levels_gained(before)
	_emit_experience()


## Setzt die Stufe direkt (Testszene, Speichern). Höhere Stufe gibt die Punkte dazu.
func set_level(level: int) -> void:
	var before := progression.level
	if progression.set_level(level) > 0:
		_on_levels_gained(before)
	_emit_experience()


## Setzt einen Rang ohne Punkte (Testszene, Tests).
func debug_set_rank(skill: SkillDef, rank: int) -> void:
	skill = _own_skill(skill)
	var was_learned := progression.is_learned(skill)
	progression.ranks[skill.id] = clampi(rank, 0, progression.get_max_rank(skill))
	if not was_learned and rank > 0:
		_place_new_skill(skill)
	_update_basic_attack()
	EventBus.skill_tree_changed.emit(progression.build_state())


func get_cooldown_left(skill: SkillDef) -> float:
	return _cooldowns.get(skill.id, 0.0) if skill != null else 0.0


## Verkürzt eine laufende Abklingzeit. Sendet skill_cooldown_started mit der Restzeit.
func reduce_cooldown(skill: SkillDef, seconds: float) -> void:
	var left := get_cooldown_left(skill)
	if left <= 0.0:
		return
	left = maxf(left - seconds, 0.0)
	_cooldowns[skill.id] = left
	EventBus.skill_cooldown_started.emit(skill, left)


func clear_cooldowns() -> void:
	for id: StringName in _cooldowns.keys():
		_cooldowns[id] = 0.0
		var skill := class_def.find_skill(id)
		if skill != null:
			EventBus.skill_cooldown_started.emit(skill, 0.0)


## Prozent-Quelle am Spieler für duration Sekunden (Schreie, Zorn der Ahnen).
func apply_buff(key: StringName, block: StatBlock, duration: float) -> void:
	Stats.set_percent_source(player, key, block)
	_buffs[key] = duration


func has_buff(key: StringName) -> bool:
	return _buffs.has(key)


func add_background(cast: SkillCast) -> void:
	background_casts.append(cast)
	cast.start()


## Zählt Einsätze eines Skills (für „jeder dritte Schlag“). Liefert den neuen Stand.
func count_combo(skill: SkillDef) -> int:
	_combo[skill.id] = _combo.get(skill.id, 0) + 1
	return _combo[skill.id]


## Ein Einsatz hat landed Gegner getroffen: Wut für Basis-Skills und Verbesserungen.
func on_targets_hit(cast: SkillCast, landed: int) -> void:
	if cast.skill.category == Enums.SkillCategory.BASIC:
		cast.generate_resource()
	var per_hit := cast.skill.get_param(&"upgrade_resource_per_hit")
	if cast.mods.upgraded and per_hit > 0.0:
		var counted := mini(landed, int(cast.skill.get_param(&"upgrade_resource_max_targets", 5)))
		fury.gain(per_hit * counted * cast.mods.resource_factor)


## Sendet den ganzen Stand (für eine UI, die nach dem Spieler entsteht).
func broadcast_state() -> void:
	EventBus.skill_tree_changed.emit(progression.build_state())
	_emit_experience()
	EventBus.resource_changed.emit(fury.current, fury.maximum)
	for slot in SkillLoadout.SLOT_COUNT:
		EventBus.skill_slot_changed.emit(slot, bar.get_skill(slot))


## Speicherstand (für AP9).
func to_dict() -> Dictionary:
	var data := progression.to_dict()
	data["slots"] = bar.to_ids()
	return data


func from_dict(data: Dictionary) -> void:
	progression.from_dict(data)
	var ids: Array = data.get("slots", [])
	for slot in SkillLoadout.SLOT_COUNT:
		var skill: SkillDef = null
		if slot < ids.size():
			skill = class_def.find_skill(StringName(str(ids[slot])))
		bar.slots[slot] = skill if SkillLoadout.can_hold(slot, skill) else null
	_apply_level_stats()
	_update_basic_attack()
	broadcast_state()


# --- Ablauf --------------------------------------------------------------------------------


func _process_held_input() -> void:
	for slot in range(1, SkillLoadout.SLOT_COUNT):
		var held := (
			_pressed_slots.has(slot) and Input.is_action_pressed(SkillLoadout.action_for(slot))
		)
		if not held:
			_pressed_slots.erase(slot)
		if active_cast != null:
			if active_cast.slot == slot and not held:
				active_cast.release()
			elif active_cast.slot == slot and active_cast.is_channeled():
				var point := player.mouse_ground_point()
				if point != Vector3.INF:
					active_cast.target_point = point
		elif held:
			cast_slot(slot, Vector3.INF, null, true)


func _end_active_cast() -> void:
	var cast := active_cast
	active_cast = null
	if player.state == Player.State.CASTING:
		player.end_cast()
	cast_finished.emit(cast.skill)


func _on_player_state_changed(new_state: Player.State) -> void:
	if active_cast == null or new_state == Player.State.CASTING:
		return
	var cast := active_cast
	active_cast = null
	cast.cancel()
	cast_finished.emit(cast.skill)


func _on_model_hit_frame() -> void:
	if active_cast != null:
		active_cast.on_hit_frame()


## Treffermoment des Standardangriffs, wenn Platz 0 einen gelernten Basis-Skill hat.
func _on_basic_attack(direction: Vector3) -> Array[Node3D]:
	var skill := bar.get_skill(SkillLoadout.PRIMARY_SLOT)
	var landed: Array[Node3D] = []
	if skill == null:
		return landed
	var point := player.global_position + direction * skill.attack_range
	var cast := create_cast(skill, point)
	if not cast is MeleeCast:
		return landed
	cast.slot = SkillLoadout.PRIMARY_SLOT
	EventBus.skill_cast.emit(player, skill, point)
	landed = (cast as MeleeCast).strike()
	return landed


func _update_basic_attack() -> void:
	var skill := bar.get_skill(SkillLoadout.PRIMARY_SLOT)
	if skill != null and progression.is_learned(skill):
		player.basic_attack_handler = _on_basic_attack
	else:
		player.basic_attack_handler = Callable()


func _place_new_skill(skill: SkillDef) -> void:
	if bar.find_slot(skill) >= 0:
		return
	var slot := bar.first_free_slot(skill)
	if slot >= 0:
		assign_slot(slot, skill)


func _start_cooldown(skill: SkillDef) -> void:
	if skill.cooldown <= 0.0:
		return
	var reduction := clampf(
		Stats.get_stat(player, Enums.Stat.COOLDOWN_REDUCTION), 0.0, MAX_COOLDOWN_REDUCTION
	)
	var duration := skill.cooldown * (1.0 - reduction)
	_cooldowns[skill.id] = duration
	EventBus.skill_cooldown_started.emit(skill, duration)


func _tick_cooldowns(delta: float) -> void:
	for id: StringName in _cooldowns.keys():
		_cooldowns[id] = maxf(_cooldowns[id] - delta, 0.0)


func _tick_buffs(delta: float) -> void:
	for key: StringName in _buffs.keys():
		_buffs[key] -= delta
		if _buffs[key] <= 0.0:
			_buffs.erase(key)
			Stats.remove_source(player, key)


func _on_levels_gained(from_level: int) -> void:
	for level in range(from_level + 1, progression.level + 1):
		EventBus.player_level_up.emit(level)
	_apply_level_stats()
	player.health.reset_to_full()
	EventBus.skill_tree_changed.emit(progression.build_state())


func _apply_level_stats() -> void:
	if class_def.stats_per_level == null:
		return
	var block := StatBlock.new()
	for stat: Enums.Stat in class_def.stats_per_level.values:
		block.set_value(stat, class_def.stats_per_level.values[stat] * (progression.level - 1))
	Stats.set_flat_source(player, LEVEL_SOURCE, block)


func _emit_experience() -> void:
	EventBus.experience_changed.emit(
		progression.experience, progression.required_experience(), progression.level
	)


func _update_fury_maximum() -> void:
	fury.set_maximum(Stats.get_stat(player, Enums.Stat.RESOURCE_MAX))


func _on_fury_changed(current: float, maximum: float) -> void:
	EventBus.resource_changed.emit(current, maximum)


func _on_experience_awarded(amount: int, _source: Node3D) -> void:
	add_experience(amount)


func _on_rank_up_requested(skill: SkillDef) -> void:
	rank_up(skill)


func _on_slot_assign_requested(slot: int, skill: SkillDef) -> void:
	assign_slot(slot, skill)


## Der eigene SkillDef mit derselben id (die UI kann Kopien schicken).
func _own_skill(skill: SkillDef) -> SkillDef:
	if skill == null:
		return null
	var own := class_def.find_skill(skill.id)
	return own if own != null else skill
