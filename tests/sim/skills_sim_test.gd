class_name SkillsSimTest
extends SimTest
## Grundlage der Simulationstests für die AP5-Testszene skills_test: lädt die Szene, schaltet
## kritische Treffer ab und sammelt alle Treffer (damage_dealt) für Auswertungen.
##
## Aufbau der Szene (debug/skills_test.tscn): Spieler bei (0, 0, 6). Puppen „Front“ bei z ≈ 1,
## „Pack“ bei z ≈ -4, „Far“ bei (8,5, -9). Alle Puppen passiv mit 400 Leben.

var _scene: Node3D
var _player: Player
var _skills: SkillUser
var _hits: Array[HitInfo] = []
var _results: Array[DamageResult] = []


func before_each() -> void:
	Combat.hit_stop_enabled = false
	_scene = await load_scene("skills_test")
	_player = _scene.get("player")
	_player.input_enabled = false
	_skills = _scene.get("skills")
	# Keine kritischen Treffer, damit Schadensvergleiche genau sind.
	Stats.set_flat_source(
		_player, &"test:no_crit", StatBlock.from_dict({Enums.Stat.CRIT_CHANCE: -1.0})
	)
	_hits.clear()
	_results.clear()
	EventBus.damage_dealt.connect(_on_damage_dealt)
	await wait_physics_frames(5)


func after_each() -> void:
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)
	Combat.hit_stop_enabled = true
	Engine.time_scale = 1.0


func _on_damage_dealt(hit: HitInfo, result: DamageResult) -> void:
	_hits.append(hit)
	_results.append(result)


# --- Hilfen --------------------------------------------------------------------------------


func _skill(id: StringName) -> SkillDef:
	return _skills.class_def.find_skill(id)


func _dummy(dummy_name: String) -> TrainingDummy:
	return _scene.get_node("Dummies/%s" % dummy_name) as TrainingDummy


func _damaged_dummies() -> Array[TrainingDummy]:
	var result: Array[TrainingDummy] = []
	for dummy: TrainingDummy in _scene.get_dummies():
		if dummy.health.current < dummy.health.maximum:
			result.append(dummy)
	return result


## Schaden, den ein Skill verursacht hat (Summe über alle Treffer).
func _damage_by(id: StringName, type: int = -1) -> float:
	var total := 0.0
	for i in _hits.size():
		var hit := _hits[i]
		if hit.skill != null and hit.skill.id == id and (type < 0 or hit.type == type):
			total += _results[i].amount
	return total


func _hit_count(id: StringName) -> int:
	var count := 0
	for hit in _hits:
		if hit.skill != null and hit.skill.id == id:
			count += 1
	return count


func _place_player(position: Vector3, facing: Vector3 = Vector3.FORWARD) -> void:
	_player.global_position = position
	_player.facing = facing
	_player.velocity = Vector3.ZERO
	await wait_physics_frames(2)


func _wait_until(condition: Callable, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if condition.call():
			return true
		await wait_physics_frames(1)
		waited += 1.0 / Engine.physics_ticks_per_second
	return condition.call()


func _wait_cast_done(timeout: float = 3.0) -> bool:
	return await _wait_until(
		func() -> bool: return _skills.active_cast == null and _skills.background_casts.is_empty(),
		timeout
	)
