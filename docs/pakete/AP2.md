# AP2 – Spieler, Steuerung und Kampfkern

Stand: 22.09.2026 · Godot 4.7.2

## Was gebaut ist

| Bereich | Wo |
|---|---|
| Spielerfigur (`CharacterBody3D`, Klasse `Player`) mit Kapsel als Platzhalter | `player/player.tscn`, `player/player.gd` |
| Werte der Figur (Leben, Angriff, Rolle, Trank) als Daten | `player/player_config.gd`, `data/player/warrior.tres` |
| Klicken zum Laufen mit Wegfindung (`NavigationAgent3D`), Halten zum Folgen, WASD relativ zur Kamera | `player/player.gd` |
| Ausweichrolle: 4,5 m, 0,28 s unverwundbar, durch Gegner hindurch, 2 s Abklingzeit | `player/player.gd` |
| Zielauswahl unter der Maus: Strahl auf Trefferflächen, sonst nächster Gegner am Bodenpunkt | `Player.pick_target_at_screen()` |
| Standardangriff: Bogen 120° vor der Figur, Treffermoment nach 40 % der Angriffsdauer | `Player._perform_hit()`, `combat/melee_query.gd` |
| Heiltrank: 4 Ladungen, heilt 35 %, 3 besiegte Gegner füllen eine Ladung | `player/potion_belt.gd` |
| Tod und `revive()` | `player/player.gd` |
| Komponenten `StatsComponent`, `HealthComponent`, `HurtboxComponent`, `HitboxComponent`, `StatusEffectsComponent`, `KnockbackComponent`, Suchhilfe `Components` | `components/` |
| Echter Dienst `Combat`: Rüstung, Resistenzen, kritische Treffer, Unverwundbarkeit, Leben bei Treffer, Rückstoß, Trefferstopp | `combat/combat_service.gd`, Stellschrauben in `data/combat/combat_config.tres` |
| Echter Dienst `Stats`: Grundwert + feste Quellen (Ausrüstung, Stufe) × Prozent-Quellen (Effekte) | `combat/stats_service.gd`, `components/stats_component.gd` |
| Statuseffekte Verlangsamung, Brennen, Betäubung | `combat/status_effect_def.gd`, `data/status_effects/*.tres` |
| Trainingspuppen, passiv oder zurückschlagend (mit Vorwarnung und Effekt) | `combat/training_dummy.tscn` |
| Anbindung an AP4: `Inventory` und `Equipment` hängen am Spieler, Ausrüstung zählt in die Werte, Klick auf Beute läuft hin und hebt auf | `player/player.tscn`, `Player.pick_up()` |
| Testszene | `debug/combat_test.tscn` |
| Tests: Schadensformel, Werte, Leben, Effekte, Trank, Zielsuche, Hitbox, Simulation in der Testszene | `tests/unit/test_combat_formula.gd` und weitere, `tests/sim/test_combat_scene.gd` |

## Schadensformel

1. Kritischer Treffer mit `CRIT_CHANCE` der Quelle (nur wenn `hit.can_crit`): × (1 + `CRIT_DAMAGE`).
2. Physisch: × (1 − Rüstung / (Rüstung + 200)), höchstens 85 % Minderung.
   Feuer, Kälte, Gift: × (1 − Resistenz), Resistenz zwischen −100 % und 75 %.
3. Unverwundbares Ziel: kein Schaden, `result.evaded = true`, kein `damage_dealt`.
4. Danach: Leben bei Treffer für die Quelle, Rückstoß `hit.knockback` in Metern, Signale.

`HitInfo.base` ist der Schaden vor dieser Rechnung; der Angreifer rechnet Waffenschaden × Skill-Faktor
selbst aus (Standardangriff: `DAMAGE` × 1,0).

## Wie man es testet

```bash
tools/run_tests.sh                               # alle Tests, auch die Simulation
godot --path . -- --scene=combat_test            # Testszene mit Grafik
SpielJBR.exe --scene=combat_test                 # dasselbe im Windows-Build
```

In der Testszene: Hinter der Mauer stehen zwei Puppen und eine gepanzerte Puppe (halber Schaden).
Rechts stehen drei Puppen, die nach roter Vorwarnung zurückschlagen und verlangsamen, brennen
oder betäuben. Links unten stehen Leben, Tränke, Abklingzeit der Rolle, Zustand und das Ziel unter
der Maus. R setzt alles zurück.

Tasten: Linksklick laufen oder angreifen (halten: folgen oder weiter schlagen), WASD laufen
(Linksklick schlägt dann im Stand zur Maus), Leertaste Ausweichrolle, Q Heiltrank.

## Schnittstellen für andere Pakete

- **Alle:** Komponenten findet `Components.health(figur)`, `.stats()`, `.status_effects()`,
  `.knockback()`, `.hurtbox()`, `Components.is_alive()`, `Components.is_stunned()`.
  Physik-Ebenen stehen in `PhysicsLayers` (world, player, enemy, hurtbox, loot).
- **AP3 (Gegner):** Aufbau wie `combat/training_dummy.tscn`: `CharacterBody3D` auf Ebene
  `ENEMY` mit `Stats`, `Health`, `Hurtbox` (faction ENEMY), `StatusEffects`, `Knockback`.
  Werte aus `EnemyDef.base_stats` in `StatsComponent.base_stats`. Schaden immer über
  `Combat.apply_damage()`; Geschosse und Flächen über `HitboxComponent`, Nahkampf über
  `MeleeQuery.find_targets()`. Tod: `HealthComponent.died`; `Combat` sendet `entity_died`.
  Betäubt: `Components.is_stunned(self)` abfragen und nichts tun. Rückstoß: in
  `_physics_process` `knockback.consume(delta)` auf die Geschwindigkeit addieren.
- **AP4 (Beute):** Ausrüstung wirkt über `Equipment.stats_changed` automatisch als Quelle
  `&"equipment"`. Ohne `Equipment`-Knoten wertet `Stats` `EventBus.player_equipped` je Platz aus.
- **AP5 (Skills):** Befehle `Player.attack()`, `attack_direction()`, `dodge()`, `stop()`;
  `Player.state`, `Player.facing`, `Player.can_act()`. Stufenwerte als
  `Stats.set_flat_source(player, &"level", block)`, Buffs als
  `Stats.set_percent_source(player, &"shout", block)`. Wucht: `Combat.hit_stop_for(results)`.
  Der Standardangriff ist fest eingebaut; wenn „Hieb“ als Skill kommt, kann AP5 ihn über
  `attack_landed` ergänzen oder die Linksklick-Belegung übernehmen (dann bitte hier absprechen).
- **AP7 (UI):** `EventBus.entity_health_changed` (jede `HealthComponent`), `player_health_changed`, `potion_charges_changed`,
  `status_effect_changed`, `hovered_target_changed` (Gegner unter der Maus für den Lebensbalken),
  `damage_dealt` mit `result.crit` für Schadenszahlen. Abklingzeit der Rolle:
  `Player.get_dodge_cooldown_left()`.
- **AP8 (Modelle):** Szene unter `assets/characters/warrior.tscn` ablegen, sie ersetzt die Kapsel
  automatisch. Das Modell schaut nach −Z. Optional am Wurzelknoten: `play_action(name, speed)`
  mit den Namen `idle`, `run`, `attack` (speed = Angriffe pro Sekunde), `dodge`, `stunned`,
  `death`; `set_move_speed(anteil)` mit 0 bis 1; Signal `hit_frame` aus einer Methodenspur,
  dann kommt der Treffermoment aus der Animation.
- **AP1 (Grafik):** Treffer-Aufblitzen und Kamerawackeln bei kritischen Treffern und Todesstößen
  laufen schon; Effekte und Schadenszahlen hängen an `damage_dealt`.
- **AP9 (Spielablauf):** `Player.revive()`, Tod über `entity_died` mit `entity == Game.player`.
  Balancing in `data/player/warrior.tres` und `data/combat/combat_config.tres`.

## Vertragsänderungen

Ein Commit mit Präfix `contracts:`:
- `EventBus`: `player_health_changed`, `potion_charges_changed`, `status_effect_changed`,
  `hovered_target_changed`.
- `DamageResult.evaded`.
- Neue Klasse `PhysicsLayers`, Ebenennamen in `project.godot`.

## Abweichungen vom Plan und Festlegungen

- **Trefferstopp** senkt kurz `Engine.time_scale` (auf 0,05 für 45 ms, 85 ms bei kritischen
  Treffern und Todesstößen). Wer selbst die Zeitskala ändert (Zeitlupe), muss das mit
  `Combat.is_hit_stop_active()` abstimmen. Tests schalten ihn mit `Combat.hit_stop_enabled` ab.
- **Trainingspuppen** liegen in `combat/`, weil `enemies/` AP3 gehört.
- **Branch:** gearbeitet auf `claude/project-thread-ikl43y` (Vorgabe der Session) statt `ap2-player`.

## Offen

- Spielgefühl (Tempo, Reichweite, Rolle, Trefferstopp) ist nur headless geprüft. Joshua sollte
  die Testszene im Windows-Build ausprobieren; Zahlen stehen in `data/player/warrior.tres`.
- Angriffe laufen ohne Animation; mit Modellen aus AP8 kommt der Treffermoment aus der Animation.
- Spielerlicht, Treffer-Effekte und Schadenszahlen kommen von AP1 und AP7.
- Kein Umriss für den Gegner unter der Maus (AP1 oder AP7 über `hovered_target_changed`).
