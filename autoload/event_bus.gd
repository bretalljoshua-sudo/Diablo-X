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

# --- Ergänzt von AP2 (Spieler und Kampf) ---

## Leben des Spielers hat sich geändert (für HUD, AP7).
signal player_health_changed(current: float, maximum: float)
## Heiltrank-Ladungen des Spielers. progress = Fortschritt zur nächsten Ladung (0 bis 1).
signal potion_charges_changed(charges: int, maximum: int, progress: float)
## Ein Statuseffekt (Verlangsamung, Brennen, Betäubung) beginnt oder endet an einer Figur.
signal status_effect_changed(entity: Node3D, effect_id: StringName, active: bool)
## Die Figur unter der Maus hat gewechselt (null = keine). Für Gegner-Lebensbalken und Umriss.
signal hovered_target_changed(target: Node3D)

# --- Ergänzt von AP6 (Dungeon und Dorf) ---

## Die aktuelle Ebene wird gleich abgebaut (Wechsel zur nächsten Ebene oder ins Dorf).
## Wer Knoten in die Ebene gesetzt hat (Gegner, Beute), räumt sie hier weg.
signal level_unloading(layout: LevelLayout)
## Ein Ebenenwechsel beginnt, der Ladebildschirm ist sichtbar. target_depth wie LevelConfig.depth.
signal level_transition_started(target_depth: int)

# --- Ergänzt von AP7 (UI und Inventar) ---
# Die UI liest nur. Wer den Zustand besitzt, sendet ihn; Wünsche der UI kommen als *_requested.

## Leben einer beliebigen Figur (Gegner, Boss). Für Lebensbalken über Gegnern und den Bossbalken.
signal entity_health_changed(entity: Node3D, current: float, maximum: float)
## Erfahrung des Spielers innerhalb der aktuellen Stufe (AP5).
signal experience_changed(current: int, required: int, level: int)
## Kompletter Stand des Skillbaums (AP5): nach jeder Änderung an Rängen oder Punkten neu senden.
signal skill_tree_changed(state: SkillTreeState)
## Platz der Skillleiste belegt (AP5). slot 0 = Linksklick, 1 = Rechtsklick,
## 2 bis 5 = Tasten 1 bis 4. skill null = leer.
signal skill_slot_changed(slot: int, skill: SkillDef)
## Abklingzeit eines Skills beginnt (AP5). duration in Sekunden, nach Abklingzeitverringerung.
signal skill_cooldown_started(skill: SkillDef, duration: float)
## Die UI möchte einen Rang mehr für den Skill. AP5 prüft und antwortet mit skill_tree_changed.
signal skill_rank_up_requested(skill: SkillDef)
## Die UI möchte einen Skill auf einen Platz der Leiste legen. AP5 antwortet mit skill_slot_changed.
signal skill_slot_assign_requested(slot: int, skill: SkillDef)
## Bosskampf beginnt oder endet (AP9). Leben kommt über entity_health_changed.
signal boss_encounter_started(boss: Node3D, display_name: String)
signal boss_encounter_ended(boss: Node3D)
## Ein Händler öffnet sein Angebot. Gekaufte Gegenstände entfernt die UI aus stock.
signal merchant_opened(merchant_name: String, stock: Array[ItemInstance])
signal merchant_item_bought(item: ItemInstance, price: int)
signal merchant_item_sold(item: ItemInstance, price: int)
## Ein Fenster der UI (Inventar, Skillbaum, Karte, Händler, Pause) wurde geöffnet oder geschlossen.
signal ui_window_toggled(window: StringName, open: bool)

# --- Ergänzt von AP3 (Gegner und KI) ---

## Erfahrung für den Spieler, gesendet einmal pro besiegtem Gegner (AP3). amount ist schon mit
## Stufe und Elite-Bonus verrechnet, source ist der Gegner. AP5 vergibt damit Erfahrung und Stufen.
signal experience_awarded(amount: int, source: Node3D)

# --- Ergänzt von AP5 (Skills und Krieger) ---

## Ein Skill konnte nicht eingesetzt werden. reason: &"cooldown", &"resource",
## &"not_learned", &"busy" (Figur betäubt, tot oder in einer anderen Aktion).
signal skill_cast_failed(skill: SkillDef, reason: StringName)
