extends Node3D
## Testszene von AP2 (Spieler und Kampf). Start: --scene=combat_test
##
## Links hinter der Mauer stehen passive Puppen (eine gepanzert), rechts drei Puppen, die
## zurückschlagen und verlangsamen, brennen oder betäuben. Das Navigationsnetz wird beim
## Start aus den Kollisionsformen gebacken, der Spieler läuft per Klick um die Mauer herum.
## R setzt alle Puppen und den Spieler zurück.

@onready var player: Player = $Player
@onready var nav_region: NavigationRegion3D = $NavRegion
@onready var rig: CameraRig = $CameraRig
@onready var status_label: Label = $Hud/Status


func _ready() -> void:
	nav_region.bake_navigation_mesh(false)
	rig.target = player
	rig.global_position = player.global_position


func _process(_delta: float) -> void:
	status_label.text = _status_text()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_R:
		reset()


func get_dummies() -> Array[TrainingDummy]:
	var result: Array[TrainingDummy] = []
	for child in $Dummies.get_children():
		if child is TrainingDummy:
			result.append(child)
	return result


## Passive Puppen (schlagen nicht zurück), zum Beispiel für Bots.
func get_passive_dummies() -> Array[TrainingDummy]:
	return get_dummies().filter(func(d: TrainingDummy) -> bool: return d.attack_damage <= 0.0)


func reset() -> void:
	for dummy in get_dummies():
		dummy.health.revive(1.0)
	if player.is_dead():
		player.revive()
	else:
		player.health.reset_to_full()
		player.potions.refill()


func _status_text() -> String:
	var lines: Array[String] = []
	var h := player.health
	lines.append("Leben: %d / %d" % [ceili(h.current), roundi(h.maximum)])
	lines.append(
		(
			"Heiltränke: %d / %d  (nächste Ladung %d %%)"
			% [
				player.potions.charges,
				player.potions.max_charges,
				roundi(player.potions.progress * 100)
			]
		)
	)
	var dodge_left := player.get_dodge_cooldown_left()
	lines.append("Ausweichrolle: %s" % ("bereit" if dodge_left <= 0.0 else "%.1f s" % dodge_left))
	var effects := player.status_effects.get_active_ids()
	lines.append("Zustand: %s" % Player.State.keys()[player.state].to_lower())
	if not effects.is_empty():
		lines[-1] += "  [%s]" % ", ".join(effects)
	if player.hovered_target != null:
		var target_health := Components.health(player.hovered_target)
		var target_name: String = player.hovered_target.get("display_name")
		if target_health != null:
			lines.append(
				(
					"Ziel: %s  %d / %d"
					% [target_name, ceili(target_health.current), roundi(target_health.maximum)]
				)
			)
	return "\n".join(lines)
