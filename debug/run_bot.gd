class_name RunBot
extends ArenaBot
## Bot für den ganzen Durchlauf (AP9): spielt die Spielerfigur in der Spielszene (GameSession)
## vom Dorf bis zum besiegten Boss und zurück, so wie ein Mensch mit Maus und Tastatur.
##
## Kampf, Ausweichen, Tränke und Feuer übernimmt ArenaBot (AP3). Dazu kommen:
##   - Skills: Spaltschlag bei genug Wut, Kriegsschrei und Zorn der Ahnen, wenn es sich lohnt
##   - Skillpunkte nach fester Reihenfolge verteilen, bessere Ausrüstung sofort anlegen
##   - Beute aufsammeln, im Dorf Überflüssiges verkaufen
##   - Ebene leer: zur Treppe; Bossraum: Boss, Truhe, Portal
##   - Tod: am Eingang der Ebene erwachen
## Für Simulationstests (tests/sim/test_full_run.gd) und zum Zuschauen (--bot).

## Nimmt ein Ziel aus der Wahl, wenn die Figur so lange nicht näher kommt.
const STUCK_TIME := 4.0
const IGNORE_TIME := 20.0
const LOOT_RANGE := 30.0
const REVIVE_DELAY := 2.0
const SKILL_ORDER: Array[StringName] = [
	&"cleave",
	&"strike",
	&"cleave",
	&"war_cry",
	&"cleave",
	&"war_cry",
	&"charge",
	&"cleave",
	&"ancients",
	&"cleave",
	&"strike",
	&"war_cry",
	&"ancients",
	&"strike",
	&"charge",
	&"whirlwind",
	&"leap",
	&"strike",
	&"war_cry",
	&"ancients",
]

var session: Node
## Schreibt alle so viele Sekunden den Zustand ins Log (0 = nie).
var log_interval: float = 0.0
## Laufende Aufgabe, für Anzeige und Tests.
var task: StringName = &"idle"
var kills: int = 0
var deaths: int = 0
var items_equipped: int = 0
var items_sold: int = 0
## Je Ebene: Sekunden, Spielerstufe beim Betreten und beim Verlassen.
var level_log: Array[Dictionary] = []

var _skills: SkillUser
var _ignored: Dictionary[Node, float] = {}
var _stuck_target: Node
var _stuck_left: float = STUCK_TIME
var _stuck_distance: float = INF
var _dead_time: float = 0.0
var _level_time: float = 0.0
var _clock: float = 0.0
var _sold_this_visit: bool = false
var _log_left: float = 0.0
var _next_move_order: float = 0.0


func _ready() -> void:
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.level_loaded.connect(_on_level_loaded)
	EventBus.loot_picked_up.connect(
		func(_item: ItemInstance) -> void: equip_upgrades.call_deferred()
	)


func _physics_process(delta: float) -> void:
	_clock += delta
	_level_time += delta
	_log_left -= delta
	if log_interval > 0.0 and _log_left <= 0.0:
		_log_left = log_interval
		print(describe())
	if not enabled or player == null or not is_instance_valid(player):
		return
	if _skills == null:
		_skills = SkillUser.find_on(player)
	if player.is_dead():
		_handle_death(delta)
		return
	_dead_time = 0.0
	if player.health.get_ratio() < POTION_BELOW and player.potions.charges > 0:
		if player.drink_potion():
			potions_used += 1
	if World.is_transitioning:
		task = &"loading"
		return
	_spend_points()
	_close_windows()
	var target := _pick_target()
	if target != null:
		task = &"fight"
		super._physics_process(delta)
		_use_skills(target)
		_watch_progress(target, delta)
		return
	var loot := _nearest_loot()
	if loot != null:
		task = &"loot"
		if player.pickup_target != loot:
			player.pick_up(loot)
		_watch_progress(loot, delta)
		return
	_travel(delta)


# --- Ziele ---------------------------------------------------------------------------------------


func _pick_target() -> Enemy:
	var best: Enemy = null
	var best_score := INF
	var arena := _arena()
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_active() or _is_ignored(enemy):
			continue
		# Den Boss erst angreifen, wenn der Kampf läuft (vorher steht er hinter dem Gitter).
		if arena != null and enemy == arena.boss and arena.state == BossArena.State.WAITING:
			continue
		var distance := enemy.global_position.distance_to(player.global_position)
		var score := distance
		if enemy.type.is_ranged() and distance < 9.0:
			score -= 4.0
		if enemy.has_shield():
			score += 6.0
		if score < best_score:
			best_score = score
			best = enemy
	return best


func _nearest_loot() -> GroundItem:
	var best: GroundItem = null
	var best_distance := LOOT_RANGE
	for node in get_tree().get_nodes_in_group(GroundItem.GROUP):
		var item := node as GroundItem
		if item == null or not item.is_inside_tree() or _is_ignored(item):
			continue
		if item.item != null and not player.inventory.has_space_for(item.item):
			continue
		var distance := item.global_position.distance_to(player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = item
	return best


## Wer das Ziel so lange nicht näher bringt, lässt es eine Weile links liegen (hinter Wänden,
## außerhalb des Netzes).
func _watch_progress(target: Node3D, delta: float) -> void:
	var distance := target.global_position.distance_to(player.global_position)
	if target != _stuck_target:
		_stuck_target = target
		_stuck_left = STUCK_TIME
		_stuck_distance = distance
		return
	# Nah am Gegner zählt als Fortschritt, nah an Beute nur, bis sie aufgehoben ist.
	var close := distance < 2.5 and target is Enemy
	if distance < _stuck_distance - 0.5 or close:
		_stuck_distance = distance
		_stuck_left = STUCK_TIME
		return
	_stuck_left -= delta
	var arena := _arena()
	if arena != null and target == arena.boss:
		# Den Boss nie aufgeben: er läuft selbst auf den Spieler zu.
		_stuck_left = STUCK_TIME
		return
	if _stuck_left <= 0.0:
		_ignored[target] = _clock + IGNORE_TIME
		_stuck_target = null
		player.stop()


func _is_ignored(node: Node) -> bool:
	if not _ignored.has(node):
		return false
	if _clock > _ignored[node]:
		_ignored.erase(node)
		return false
	return true


# --- Wege ----------------------------------------------------------------------------------------


func _travel(_delta: float) -> void:
	var level := Level.get_active()
	if level == null or level.layout == null:
		return
	var layout := level.layout
	if layout.depth == World.VILLAGE_DEPTH:
		if not _sold_this_visit:
			_sell_leftovers()
		task = &"to_dungeon"
		_go(layout.exits[0] if not layout.exits.is_empty() else layout.player_start)
		return
	var arena := _arena()
	if arena != null and arena.layout == layout:
		match arena.state:
			BossArena.State.WAITING:
				task = &"to_boss"
				_go(layout.markers.get(&"boss_room_center", arena.boss.global_position))
			BossArena.State.FIGHTING:
				task = &"to_boss"
				_go(arena.boss.global_position)
			BossArena.State.DEFEATED:
				if arena.chest != null and not arena.chest.is_open:
					task = &"to_chest"
					_go(arena.chest.global_position)
				else:
					task = &"to_portal"
					_go(layout.markers.get(&"portal", layout.player_start))
		return
	task = &"to_stairs"
	if not layout.exits.is_empty():
		_go(layout.exits[0])


func _go(point: Vector3) -> void:
	if player.state == Player.State.MOVING and player.has_move_target():
		return
	# Nicht in jedem Takt neu befehlen, sonst kommt die Wegfindung nie zum Zug.
	if _clock < _next_move_order:
		return
	_next_move_order = _clock + 0.5
	if (
		Vector2(point.x - player.global_position.x, point.z - player.global_position.z).length()
		< 0.6
	):
		return
	player.move_to(point)


# --- Figur verbessern ----------------------------------------------------------------------------


func _spend_points() -> void:
	if _skills == null or _skills.progression.points <= 0:
		return
	# Reihenfolge wie geplant: der n-te Eintrag eines Skills meint Rang n.
	var wanted: Dictionary[StringName, int] = {}
	for id in SKILL_ORDER:
		wanted[id] = wanted.get(id, 0) + 1
		var skill := _skills.class_def.find_skill(id)
		if skill == null or _skills.progression.get_rank(skill) >= wanted[id]:
			continue
		if _skills.progression.can_rank_up(skill) and _skills.rank_up(skill):
			return
	for skill in _skills.class_def.skills:
		if _skills.progression.can_rank_up(skill) and _skills.rank_up(skill):
			return


func _use_skills(target: Enemy) -> void:
	if _skills == null or _skills.active_cast != null or not player.can_act():
		return
	var distance := target.global_position.distance_to(player.global_position)
	var near := _enemies_near(6.0)
	var is_boss := BossController.find_on(target) != null
	var point := target.global_position
	if _ready_skill(&"ancients") and (is_boss or near >= 5) and distance < 9.0:
		_skills.try_cast(_skill(&"ancients"), point, target, -1, true)
	elif _ready_skill(&"war_cry") and (is_boss or near >= 3) and distance < 5.0:
		_skills.try_cast(_skill(&"war_cry"), player.global_position, null, -1, true)
	elif (
		_ready_skill(&"cleave")
		and distance < 2.8
		and _skills.fury.current >= _skill(&"cleave").cost
	):
		_skills.try_cast(_skill(&"cleave"), point, target, -1, true)
	elif _ready_skill(&"charge") and distance > 4.0 and distance < 8.0:
		_skills.try_cast(_skill(&"charge"), point, target, -1, true)


func _skill(id: StringName) -> SkillDef:
	return _skills.class_def.find_skill(id)


func _ready_skill(id: StringName) -> bool:
	var skill := _skill(id)
	return skill != null and _skills.check_cast(skill) == &""


func _enemies_near(radius: float) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and enemy.is_active():
			if enemy.global_position.distance_to(player.global_position) < radius:
				count += 1
	return count


## Legt bessere Gegenstände an, sobald sie im Inventar liegen.
func equip_upgrades() -> void:
	var inventory := player.inventory
	var equipment := player.equipment
	for item in inventory.get_items():
		var slot := equipment.choose_slot(item)
		if slot < 0:
			continue
		var current := equipment.get_item(slot as Enums.Slot)
		if current == null or ItemCompare.is_upgrade(current, item):
			if equipment.equip_from_inventory(inventory, item, slot):
				items_equipped += 1


## Im Dorf: alles verkaufen, was nicht angelegt ist.
func _sell_leftovers() -> void:
	_sold_this_visit = true
	equip_upgrades()
	for item in player.inventory.get_items():
		if player.inventory.sell_item(item) > 0:
			items_sold += 1


func _close_windows() -> void:
	var ui := session.get(&"game_ui") as GameUI if session != null else null
	if ui != null and ui.is_any_window_open():
		ui.close_all_windows()


# --- Tod -----------------------------------------------------------------------------------------


func _handle_death(delta: float) -> void:
	task = &"dead"
	_dead_time += delta
	if _dead_time >= REVIVE_DELAY and session != null and session.has_method(&"revive"):
		_dead_time = 0.0
		deaths += 1
		session.call(&"revive", &"level")


func _arena() -> BossArena:
	return session.get(&"arena") as BossArena if session != null else null


func _on_entity_died(entity: Node3D, killer: Node3D) -> void:
	if killer == player and entity is Enemy:
		kills += 1


func _on_level_loaded(layout: LevelLayout) -> void:
	if not level_log.is_empty():
		level_log[-1]["seconds"] = _level_time
		level_log[-1]["level_out"] = _skills.progression.level if _skills != null else 1
	(
		level_log
		. append(
			{
				"depth": layout.depth,
				"level_in": _skills.progression.level if _skills != null else 1,
				"seconds": 0.0,
			}
		)
	)
	_level_time = 0.0
	_ignored.clear()
	if layout.depth == World.VILLAGE_DEPTH:
		_sold_this_visit = false


## Kurzer Zustand für Logs und Anzeige.
## Kennzahlen für den Simulationstest und das Balancing.
func stats() -> Dictionary:
	return {
		"kills": kills,
		"deaths": deaths,
		"potions_used": potions_used,
		"dodges": dodges,
		"items_equipped": items_equipped,
		"items_sold": items_sold,
		"levels": level_log,
	}


func describe() -> String:
	var level := Level.get_active()
	return (
		"Bot: %s · Ebene %d · Stufe %d · Pos %s · Zustand %d · Kills %d · Tode %d"
		% [
			task,
			level.depth if level != null else -1,
			_skills.progression.level if _skills != null else 1,
			str(player.global_position.snapped(Vector3.ONE * 0.1)) if player != null else "-",
			player.state if player != null else -1,
			kills,
			deaths,
		]
	)
