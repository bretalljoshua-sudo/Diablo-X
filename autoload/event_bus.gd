extends Node
## Zentrale Signale zwischen den Paketen. Pakete kennen sich nicht direkt,
## sondern senden und hören hier.
##
## Regeln: neue Signale anhängen ist erlaubt (Commit mit Präfix contracts:),
## bestehende umbenennen oder ihre Parameter ändern nicht.

@warning_ignore_start("unused_signal")

## Combat.apply_damage() hat Schaden verrechnet.
signal damage_dealt(hit: HitInfo, result: DamageResult)
## Eine Figur ist gestorben. killer darf null sein.
signal entity_died(entity: Node3D, killer: Node3D)
signal entity_spawned(entity: Node3D)
signal loot_dropped(item: ItemInstance, position: Vector3)
signal loot_picked_up(item: ItemInstance)
signal gold_changed(total: int, delta: int)
signal skill_cast(caster: Node3D, skill: SkillDef, target_position: Vector3)
## Klassenressource des Spielers (Wut).
signal resource_changed(current: float, maximum: float)
signal player_level_up(level: int)
signal player_equipped(slot: Enums.Slot, item: ItemInstance)
signal level_loaded(layout: LevelLayout)
signal boss_phase_changed(boss: Node3D, phase: int)
signal run_completed(duration_sec: float)
