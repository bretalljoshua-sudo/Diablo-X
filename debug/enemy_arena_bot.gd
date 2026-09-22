class_name ArenaBot
extends Node
## Einfacher Bot für die Arena (AP3): spielt die Spielerfigur über ihre Befehle, wie es ein
## Mensch mit Maus und Tastatur tun würde. Er greift den nächsten Gegner an (Fernkämpfer in der
## Nähe zuerst), rollt aus Vorwarnungen, die gleich treffen, verlässt brennenden Boden und
## trinkt bei wenig Leben einen Heiltrank. Dient dem Simulationstest „Bot besteht die Arena“
## und zum Zuschauen (Taste B in der Testszene).

## Rollt, wenn eine Vorwarnung in weniger als so vielen Sekunden trifft.
const DODGE_WHEN_LEFT := 0.35
const POTION_BELOW := 0.45
const RETARGET_INTERVAL := 0.25

@export var enabled: bool = false

var player: Player
var dodges: int = 0
var potions_used: int = 0

var _retarget_left: float = 0.0


func _physics_process(delta: float) -> void:
	if not enabled or player == null or player.is_dead():
		return
	if _try_dodge():
		return
	if player.health.get_ratio() < POTION_BELOW and player.potions.charges > 0:
		if player.drink_potion():
			potions_used += 1
	if _leave_fire():
		return
	_retarget_left -= delta
	if _retarget_left <= 0.0:
		_retarget_left = RETARGET_INTERVAL
		var target := _pick_target()
		if target != null and player.attack_target != target and player.can_act():
			player.attack(target, true)


func _try_dodge() -> bool:
	if player.get_dodge_cooldown_left() > 0.0 or player.state == Player.State.DODGING:
		return false
	var margin := player.hurtbox.radius + 0.15
	for node in get_tree().get_nodes_in_group(AttackTelegraph.GROUP):
		var telegraph := node as AttackTelegraph
		if telegraph == null or telegraph.get_time_left() > DODGE_WHEN_LEFT:
			continue
		if not telegraph.contains_point(player.global_position, margin):
			continue
		var direction := _escape_direction(telegraph)
		if player.dodge(direction):
			dodges += 1
			return true
	return false


## Weg aus der Fläche: bei Linien seitlich, sonst vom Mittelpunkt weg.
func _escape_direction(telegraph: AttackTelegraph) -> Vector3:
	var away := player.global_position - telegraph.global_position
	away.y = 0.0
	if telegraph.shape == AttackTelegraph.Shape.LINE:
		var forward := -telegraph.global_transform.basis.z
		forward.y = 0.0
		var side := forward.cross(Vector3.UP).normalized()
		return side if side.dot(away) >= 0.0 else -side
	if away.length_squared() < 0.01:
		return -player.facing
	return away.normalized()


func _leave_fire() -> bool:
	for node in get_tree().get_nodes_in_group(FirePatch.GROUP):
		var patch := node as FirePatch
		if patch == null or not patch.is_burning():
			continue
		var offset := player.global_position - patch.global_position
		offset.y = 0.0
		if offset.length() > patch.radius + 0.3:
			continue
		var direction := offset.normalized() if offset.length() > 0.01 else Vector3.RIGHT
		player.move_to(patch.global_position + direction * (patch.radius + 1.5))
		return true
	return false


func _pick_target() -> Enemy:
	var best: Enemy = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_active() or not enemy.is_inside_tree():
			continue
		var distance := enemy.global_position.distance_to(player.global_position)
		var score := distance
		# Fernkämpfer und Beschwörer in Reichweite zuerst, sie sind zerbrechlich.
		if enemy.type.is_ranged() and distance < 9.0:
			score -= 4.0
		if enemy.has_shield():
			score += 6.0
		if score < best_score:
			best_score = score
			best = enemy
	return best
