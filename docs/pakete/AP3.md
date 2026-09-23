# AP3 – Gegner und KI

Stand: 22.09.2026 · auf main, headless getestet (36 eigene Tests, Bot räumt die Arena)

## Was gebaut ist

| Bereich | Wo |
|---|---|
| Gegner-Figur (`Enemy`, CharacterBody3D, Gruppe `enemies`) mit AP2-Komponenten | `enemies/enemy.gd`, `enemies/enemy.tscn` |
| KI als Zustandsautomat: Ruhen, Bemerken, Verfolgen, Angreifen, Erholen, Tot | `enemies/ai_brain.gd` (`AIBrain`) |
| Angriffe als Daten: Nahkampf-Kegel, Stampfer (Kreis), Geschoss (Linie), Beschwören | `enemies/enemy_attack.gd` (`EnemyAttack`) |
| Warnung am Boden vor jedem Angriff (Kreis, Kegel, Linie), füllt sich bis zum Treffer | `enemies/attack_telegraph.gd` |
| Geschosse (gepoolt, stoppen an Wänden) | `enemies/enemy_projectile.gd` |
| Gegnertypen (`EnemyType` erbt `EnemyDef`) | `enemies/enemy_type.gd`, Daten `data/enemies/*.tres` |
| Elite-Eigenschaften und -Regeln | `enemies/elite_affix.gd`, `enemies/elite_affixes.gd`, `enemies/elite_rules.gd`, Daten `data/enemies/elite/` |
| Feuerfelder der brennenden Elite | `enemies/fire_patch.gd` |
| Objekt-Pool | `enemies/enemy_pool.gd` (`EnemyPool`) |
| Gruppen und Spawn-Tabellen je Tiefe | `enemies/enemy_spawn_*.gd`, Daten `data/enemies/spawn_tables/depth_1.tres`, `depth_2.tres` |
| Spawner für Szenen und Ebenen | `enemies/enemy_director.gd` (`EnemyDirector`) |
| Testszenen | `debug/enemy_arena.tscn`, `debug/enemy_dungeon.tscn`, Bot `debug/enemy_arena_bot.gd` |

### Gegnertypen

| Typ | Datei | Verhalten | Angriffe |
|---|---|---|---|
| Skelett (Schwarm) | `skeleton.tres` | Nahkampf, schnell, wenig Leben | Hieb (Kegel, 0,55 s Warnung) |
| Schwerer Ghul | `ghoul.tres` | Nahkampf, langsam, viel Leben und Rüstung, kaum Rückstoß | Stampfer (Kreis 2,3 m, 1,1 s Warnung, wirft zurück), Prankenhieb |
| Skelett-Bogenschütze | `skeleton_archer.tres` | hält 5 bis 11 m Abstand, weicht zurück | Pfeil (Linie, 0,8 s Warnung, braucht Sichtlinie) |
| Kultist-Beschwörer | `cultist.tres` | hält Abstand | ruft 2 Skelette (höchstens 4 gleichzeitig), Feuerblitz |

Werte steigen je Stufe (`EnemyType.stats_for_level`), Erfahrung um 20 % je Stufe.
Beschworene Skelette geben weder Beute noch Erfahrung.

### Elite-Eigenschaften

Elite-Gegner haben 2,5-faches Leben, 1,3-fachen Schaden, 3-fache Erfahrung, sind 20 % größer,
tragen einen farbigen Ring und werfen aus `data/loot_tables/elite.tres`. Die Zahl der
Eigenschaften steigt mit der Stufe (`EliteRules.affix_count_by_level`).

| Eigenschaft | Wirkung |
|---|---|
| Schnell | läuft und schlägt schneller |
| Brennend | legt Feuerfelder unter den Spieler (erst Warnung, dann Brand) |
| Schildtragend | macht sich und Gruppenmitglieder in der Nähe kurz unverwundbar |
| Teleportierend | springt nach einer Warnung neben den Spieler |
| Vampirisch | heilt sich um einen Teil des verursachten Schadens |

## Wie man es testet

**Windows-Build** (CI-Artifact von main):

```
SpielJBR.exe --scene=enemy_arena            Wellen gegen alle Typen und eine Elite
SpielJBR.exe --scene=enemy_arena --bot      der Bot spielt die Arena
SpielJBR.exe --scene=enemy_arena --stress   60 Gegner auf einmal
SpielJBR.exe --scene=enemy_dungeon          echte Katakomben-Ebene aus AP6 mit Gegnern
SpielJBR.exe --scene=enemy_dungeon --depth=2 --bot
```

Tasten in der Arena:

| Taste | Wirkung |
|---|---|
| F5 | 5 Skelette an der Maus |
| F6 | 2 Bogenschützen und 2 Skelette |
| F7 | Ghul und 2 Skelette |
| F8 | Kultist und Skelett |
| F9 | zufälliger Elite-Gegner |
| F10 | 60 Gegner (Last) |
| B | Bot an/aus |
| X | alle Gegner töten |
| R | Arena neu starten |

Im Dungeon: F5 neue Ebene, B Bot. Steuerung des Spielers wie bei AP2 und AP5
(Linksklick, Tasten 1 bis 4, Rechtsklick, K Skillbaum).

**Headless:** `tools/run_tests.sh` (alles) oder einzeln
`tests/unit/test_enemy_data.gd`, `tests/sim/test_enemies.gd`, `test_enemy_arena_bot.gd`,
`test_enemy_performance.gd`, `test_enemy_dungeon.gd`.

Der Bot-Test ist reproduzierbar: gleicher Seed, gleicher Lauf, egal wie schnell die Maschine ist
und welche Tests vorher liefen (Seed 20260922: bestanden nach 156 s Spielzeit, 61 Rollen).
Andere Seeds: `ARENA_BOT_SEED=123` vor den Testaufruf setzen. Damit das so bleibt:
Spiel-Logik gehört in `_physics_process`, Zufall in einen Strom aus `Rng`, der nach
`Rng.set_master_seed()` neu entsteht (siehe `Combat.set_rng()` im Test).

## Schnittstellen

- **AP7 (Oberfläche):** Gegner haben `display_name`, `is_elite`, `get_health_bar_position()`
  und senden über den EventBus `entity_spawned`, `entity_health_changed`, `entity_died`.
  Kein direkter Bezug zwischen Gegnern und Oberfläche.
- **AP5 (Skills):** neues Signal `EventBus.experience_awarded(amount, source)`, einmal pro
  besiegtem Gegner, schon mit Stufe und Elite-Bonus verrechnet.
- **AP4 (Beute):** beim Tod `Loot.drop_at()` mit `normal.tres` oder `elite.tres`,
  dabei `EventBus.loot_dropped`.
- **AP6 (Welt):** `EnemyDirector` mit `auto_populate = true` füllt jede Ebene nach
  `level_loaded` (wartet, bis das Navigationsnetz steht) und räumt bei `level_unloading` ab.
  Gegner landen in `Level.get_active().actors`.
- **AP8 (Modelle):** feste Pfade `assets/characters/skeleton_swarm.tscn`, `ghoul.tscn`,
  `skeleton_archer.tscn`, `cultist_summoner.tscn`; fehlt eines, erscheint eine Kapsel.
  Animationen über `CharacterModel.play_action()` und `set_move_velocity()`.
- **AP1 (Effekte):** Meta `hit_vfx` (Skelette `bone_chips`, sonst `blood`) und `hit_height`
  an jedem Gegner. Auflösen beim Tod übernimmt AP1 über `entity_died`, Wiederherstellen beim
  Wiederverwenden aus dem Pool über `entity_spawned`.
- **AP9 (Ablauf, Boss):** `EnemyDirector` in die Spielszene hängen. Für Bosse
  `spawn_with_affixes()` oder einen eigenen `EnemyType` mit eigenen `EnemyAttack`s.

## Leistung

60 aktive Gegner in der Arena, headless gemessen mit `tests/sim/physics_tick_probe.gd`:
im Mittel etwa 1,3 bis 1,6 ms pro Physik-Takt, 95 % der Takte unter etwa 1,8 ms
(Grenze 3 ms). Gemessen wird vom Signal `physics_frame` bis zum letzten `_physics_process`,
also Skripte und `move_and_slide`; der Schritt von Jolt selbst ist nicht enthalten.
Der Engine-Monitor `TIME_PHYSICS_PROCESS` zeigt nur den höchsten Takt der letzten Sekunde
und eignet sich deshalb nicht für den Mittelwert.

Was es schnell macht: Entscheidungen nur alle 0,05 s, Pfade alle 0,4 s (versetzt),
Abstand halten über eine gemeinsame Positionsliste statt Kollisionen zwischen Gegnern,
zwischengespeicherte Komponenten.

## Abweichungen vom Plan

- Gearbeitet auf dem Session-Branch `claude/project-thread-652hbb` statt eines eigenen `ap3-…`-Branches,
  gemergt direkt nach main.
- Gegner kollidieren nicht miteinander (nur mit Welt und Spieler); sie halten per Steuerung
  Abstand. Das spart viel Rechenzeit.
- Der Trefferzeitpunkt richtet sich nach der Warnung am Boden, nicht nach der Animation.
  Die Animation wird so beschleunigt, dass ihr Treffermoment mit dem Ende der Warnung
  zusammenfällt. So ist jeder Treffer fair und vorhersehbar.
- Vertragsänderung (eigener `contracts:`-Commit): nur das neue Signal `experience_awarded`.

## Was offen ist

- Spielgefühl ist nur headless und über Screenshots geprüft, nicht mit Maus am echten PC.
- Balancing (Leben, Schaden, Dichte je Ebene) gehört zu AP9. Die Dichte steht in den
  Spawn-Tabellen (`fill_ratio`, etwa 41 Gegner auf Tiefe 1, 57 auf Tiefe 2).
- Elite-Eigenschaften sind nur durch Ringfarbe und Namen erkennbar; eigene Effekte
  (Aura, Schildkuppel) wären eine Aufgabe für AP1.
- Weitere Gegnertypen für 1.0 brauchen nur neue `.tres`-Dateien, solange die vier
  Angriffsarten reichen.
