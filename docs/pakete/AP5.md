# AP5 – Skills und Klasse Krieger

Stand: 22.09.2026 · Godot 4.7.2 · alles headless getestet

## Was gebaut ist

| Bereich | Wo |
|---|---|
| Skill-System am Spieler (Knoten `SkillUser`): Skillleiste, Wut, Abklingzeiten, Erfahrung, Stufen, Skillpunkte, Eingaben | `skills/skill_user.gd`, Szene `skills/warrior_skills.tscn` |
| Stufen 1 bis 10, Skillpunkte, Ränge, Freischaltung nach verteilten Punkten | `skills/skill_progression.gd` |
| Skillleiste mit 6 Plätzen als Datenmodell | `skills/skill_loadout.gd` (`SkillLoadout`) |
| Wut (Aufbau, Verbrauch, Maximum aus `RESOURCE_MAX`, Regeneration aus `RESOURCE_REGEN`) | `skills/resource_pool.gd` |
| Rang, Verbesserung und Aspekte je Einsatz | `skills/skill_modifiers.gd` |
| Verhalten der Skills (Nahkampf, Wirbelsturm, Schrei, Sprung, Ansturm, Ahnen, Feuerring) | `skills/skill_cast.gd`, `skills/casts/` |
| Wackeln, Effekte, Animationen mit Rückfall | `skills/skill_fx.gd` |
| Klasse Krieger als Daten (Skills, Start, Stufen) | `data/skills/warrior.tres` (`SkillClassDef`, Skript `skills/skill_class_def.gd`) |
| 7 Skills als `SkillDef` | `data/skills/*.tres` |
| Andockstelle an der Spielerfigur (AP2) | `player/player.gd`, siehe unten |
| Testszene | `debug/skills_test.tscn` |
| 49 neue Tests | `tests/unit/test_skill_*.gd`, `tests/sim/test_skills_scene.gd`, `tests/sim/test_skills_aspects.gd` |

## Die sieben Skills

Schaden ist immer ein Vielfaches des Waffenschadens (`Stats` `DAMAGE`). Jeder Rang über 1 gibt
+10 % Schaden. Ab Rang 2 wirkt die Verbesserung.

| Skill | Kategorie | Kosten / Abklingzeit | Wirkung | Verbesserung (ab Rang 2) |
|---|---|---|---|---|
| Hieb | Basis | +10 Wut bei Treffer | Schlag im 120°-Bogen, 100 %; ersetzt den Standardangriff auf Linksklick | Jeder dritte Hieb trifft rundherum mit +50 % |
| Spaltschlag | Kern | 25 Wut | Halbkreis 180°, 2,6 m, 180 %, Rückstoß | Verlangsamt 2 s um 30 % |
| Wirbelsturm | Kern, kanalisiert | 20 Wut pro Sekunde | Taste halten: 140 % pro Sekunde in 2,6 m, bewegt sich mit 60 % Tempo zur Maus | 1 Wut je getroffenem Gegner pro Takt (höchstens 3) |
| Kriegsschrei | Verteidigung | 20 s, +20 Wut | 8 s lang +20 % Schaden und +30 % Rüstung | Heilt sofort 20 % Leben |
| Sprung | Mobilität | 12 s | bis 8 m zur Maus, über Gegner hinweg, Landung 160 % in 3 m | Trifft die Landung, −4 s Abklingzeit |
| Ansturm | Mobilität | 10 s | bis 8 m geradeaus durch Gegner, je Gegner 120 % und Rückstoß | 8 Wut je Gegner (höchstens 5) |
| Zorn der Ahnen | Ultimativ | 45 s | 3 Einschläge am Zielort (bis 10 m), je 200 % in 3,5 m | 6 s lang +50 % Rüstung |

Alle Zahlen stehen in `data/skills/<id>.tres` (Felder von `SkillDef` und `params`); die Namen
der Parameter erklärt der Kopf der jeweiligen Datei in `skills/casts/`.

## Stufen und Skillpunkte

- Start: Stufe 1, Hieb auf Rang 1 und auf Linksklick, 1 freier Punkt.
- Erfahrung bis zur nächsten Stufe: 100, 160, 240, 340, 460, 600, 760, 940, 1150 (Stufe 10 ist das
  Maximum). Jede Stufe gibt **2 Skillpunkte**, +12 Leben, +1 Schaden, +3 Rüstung und füllt das Leben.
- Ein Punkt = ein Rang (höchstens 5). Kategorien werden nach verteilten Punkten lernbar:
  Basis 0, Kern 2, Verteidigung 4, Mobilität 6, Ultimativ 9.
- Ein neu gelernter Skill kommt auf den ersten freien Platz der Leiste.
- Erfahrung kommt über `EventBus.experience_awarded` (AP3 beim Tod eines Gegners).

## Skillleiste und Eingaben

| Platz | Taste | Hinweis |
|---|---|---|
| 0 | Linksklick | Nur Basis-Skills. Linksklick bleibt Laufen und Angreifen der Spielerfigur (AP2); der Treffer ist der Skill dieses Platzes (Hieb). Leer = Standardangriff aus AP2. |
| 1 | Rechtsklick | |
| 2 bis 5 | 1 bis 4 | |

Ein Skill wirkt zur Maus (auf den Gegner unter der Maus, sonst den Bodenpunkt). Taste halten
wiederholt den Skill, Wirbelsturm läuft, solange die Taste gehalten wird. Die Ausweichrolle
bricht jeden Skill ab; Betäubung und Tod ebenso.

## Aspekte (AP4)

`SkillUser` fragt bei jedem Einsatz `Equipment.get_aspects_for_tags(skill.tags)` und rechnet die
Parameter der passenden Aspekte ein (`SkillModifiers`). Die Parameter sind allgemein, jeder Aspekt
kann sie nutzen:

| Parameter | Wirkung | genutzt von |
|---|---|---|
| `damage_bonus_percent` | mehr Schaden | Sturmlauf (Ansturm), Ahnenzorn |
| `resource_bonus_percent` | mehr Wut-Aufbau | Grausamkeit (Basis) |
| `lifesteal_percent` | heilt um Anteil des Schadens | Blutdurst (Kern) |
| `knockback` | Rückstoß in Metern | Sturmlauf |
| `stun_duration` | betäubt | Erschütterung (Sprung) |
| `burn_damage_percent`, `burn_duration` | setzt in Brand | Krone der Asche (Wirbelsturm) |
| `pull_radius`, `pull_strength` | zieht Gegner heran (kanalisiert) | Mahlstrom (Wirbelsturm) |
| `fire_damage_percent`, `duration` | Feuerring um den Krieger | Flammenschrei (Schreie) |
| `extra_ancients` | zusätzliche Einschläge | Ahnenzorn |

Alle 6 Aspekte und beide einzigartigen Kräfte sind nachweisbar getestet
(`tests/sim/test_skills_aspects.gd`).

## Signale für die UI (AP7)

Alles läuft über `EventBus`. `SkillUser` sendet den ganzen Stand einmal direkt nach dem Start
(`call_deferred`). Eine UI, die später entsteht, holt ihn mit
`SkillUser.find_on(Game.player).broadcast_state()`.

| Signal | Wann | Parameter |
|---|---|---|
| `skill_slot_changed(slot, skill)` | Platz neu belegt oder geleert, beim Start für alle 6 Plätze | 0 = Linksklick, 1 = Rechtsklick, 2 bis 5 = Tasten 1 bis 4; `skill` null = leer |
| `skill_cast(caster, skill, target_position)` | Skill eingesetzt (auch jeder Hieb) | |
| `skill_cast_failed(skill, reason)` | Tastendruck ohne Wirkung | `&"cooldown"`, `&"resource"`, `&"not_learned"`, `&"busy"` |
| `skill_cooldown_started(skill, duration)` | Abklingzeit beginnt oder ändert sich | `duration` = verbleibende Sekunden nach Abklingzeitverringerung. Verkürzt (Sprung-Verbesserung) oder zurückgesetzt (0) wird mit der neuen Restzeit erneut gesendet. |
| `resource_changed(current, maximum)` | Wut ändert sich | |
| `experience_changed(current, required, level)` | Erfahrung oder Stufe ändert sich | auf Stufe 10: `required` = 0 |
| `player_level_up(level)` | je Stufenaufstieg einmal | |
| `skill_tree_changed(state)` | Ränge, Punkte oder Freischaltung ändern sich | `SkillTreeState`; `lock_reasons` z. B. „Ab 6 verteilten Punkten“ |

Die UI schickt Wünsche, `SkillUser` prüft sie:

| Wunsch | Antwort |
|---|---|
| `skill_rank_up_requested(skill)` | `skill_tree_changed`, bei einem neu gelernten Skill auch `skill_slot_changed` |
| `skill_slot_assign_requested(slot, skill)` | `skill_slot_changed` für jeden geänderten Platz (Tausch, wenn der Skill schon woanders liegt). Abgelehnt ohne Signal: nicht gelernt oder Nicht-Basis-Skill auf Linksklick. |

Für Anzeigen ohne Signal: `get_cooldown_left(skill)`, `fury.current`, `progression.get_rank(skill)`,
`progression.is_upgraded(skill)`. Für den Skillbaum-Text: `SkillDef.description`,
`upgrade_name`, `upgrade_description`, `upgrade_rank`, `cost`, `cooldown`.

## Schnittstellen für andere Pakete

- **AP2 (Spielerfigur):** `player/player.gd` lädt `skills/warrior_skills.tscn` als Kind
  (abschaltbar mit `load_skills`). Ergänzt, nichts umbenannt: Zustand `State.CASTING` (am Ende),
  `begin_cast()`, `end_cast()`, `cast_velocity`, `basic_attack_handler`, `skills`.
  `attack_direction()` und das Halten der Maustaste warten während CASTING.
- **AP3 (Gegner):** Erfahrung über `EventBus.experience_awarded(amount, source)`. Skills treffen
  alles mit `HurtboxComponent` der Gegnerfraktion, Rückstoß über `KnockbackComponent`,
  Betäubung, Brennen und Verlangsamung über `StatusEffectsComponent`.
- **AP8 (Animation):** genutzt werden `attack_1` (Hieb, über AP2), `attack_2` (Spaltschlag),
  `attack_3` (Wirbelsturm, wird wiederholt), `attack_4` (Sprung), `cast` (Kriegsschrei, Ahnen).
  Ansturm nutzt die Laufanimation. Die Dauer passt sich dem Skill an; der Treffermoment kommt aus
  der Methodenspur (`hit_frame` oder `get_event_time`), ohne Modell aus `hit_ratio`.
- **AP1 (Grafik):** `SkillFx.shake()` nutzt `CameraRig.shake()`. Effekte: `SkillFx.spawn()` ruft
  `Vfx.spawn(key, position)` mit `SkillDef.vfx_key` auf (`strike`, `cleave`, `whirlwind`,
  `war_cry`, `leap`, `charge`, `ancients`, dazu `fire_ring`). Liefert `Vfx` null (noch kein
  Effekt für den Schlüssel), leuchtet stattdessen ein Kreis am Boden auf. Außerdem hört AP1 auf `EventBus.skill_cast`.
- **AP9 (Speichern, Balancing):** `SkillUser.to_dict()` / `from_dict()` (Stufe, Erfahrung, Punkte,
  Ränge, Leiste). Balancing in `data/skills/*.tres` und `data/skills/warrior.tres`.

## Wie man es testet

```bash
tools/lint.sh
tools/run_tests.sh
godot --path . -- --scene=skills_test
SpielJBR.exe --scene=skills_test         # im Windows-Build
```

Testszene: alle sieben Skills sind gelernt, die Wut ist voll, vor dem Krieger stehen drei
Gruppen Trainingspuppen (400 Leben, stehen nach 3 s wieder auf, je 40 Erfahrung). Oben links
stehen Stufe, Erfahrung, Punkte, Leben, Wut, die Leiste mit Abklingzeiten und die Aspekte.

| Taste | Wirkung |
|---|---|
| Linksklick | Hieb (hinlaufen und zuschlagen) |
| Rechtsklick | Spaltschlag |
| 1 (halten) | Wirbelsturm |
| 2 | Kriegsschrei |
| 3 | Sprung (F8 wechselt zu Ansturm) |
| 4 | Zorn der Ahnen |
| F5 | Stufe +1 |
| F6 | alle Skills Rang +1 (ab Rang 2 verbessert) |
| F7 | nächster Satz Aspekte: Mahlstrom + Erschütterung, Blutdurst + Flammenschrei, Sturmlauf + Grausamkeit, Krone der Asche + Ahnenzorn, keine |
| F9 | Wut voll, Abklingzeiten weg |
| R | Puppen und Spieler zurücksetzen |

Die Skills gehen auch in `combat_test` und in der Welt (`world_test`), dort startet der Krieger
auf Stufe 1 mit Hieb.

## Vertragsänderungen

Ein Commit mit Präfix `contracts:`:
- `SkillDef`: `behavior`, `params`, `upgrade_name`, `upgrade_description`, `upgrade_rank`,
  `get_param()`.
- `EventBus.skill_cast_failed(skill, reason)`.

Erfahrung nutzt das Signal `experience_awarded` aus AP3.

## Festlegungen

- **Linksklick nur für Basis-Skills**, weil Linksklick auch Laufen ist. Hieb ersetzt den
  Standardangriff, AP2-Steuerung (hinlaufen, halten, WASD) bleibt unverändert.
- **Hieb ist von Anfang an gelernt**, damit der Krieger sofort kämpfen kann.
- **Zorn der Ahnen** beschwört keine eigenen Figuren, sondern lässt die Ahnen als Einschläge
  am Zielort wirken. Eigene Ahnen-Figuren mit KI wären ein Fall für AP3 oder später.
- **Skill-Treffer** gehen wie alle Treffer über `Combat.apply_damage()` mit `HitInfo.skill`
  gesetzt; Trefferstopp über `Combat.hit_stop_for()`, beim Wirbelsturm keiner (zu viele Takte).
- **Branch:** gearbeitet auf `claude/project-thread-s19cwg` (Vorgabe der Session) statt `ap5-skills`.

## Offen

- Spielgefühl (Tempo, Reichweiten, Wut-Haushalt) ist nur headless geprüft; Joshua sollte
  `skills_test` im Windows-Build ausprobieren.
- Skills laufen nicht zum Ziel, wenn es außer Reichweite ist (Spaltschlag schlägt im Stand).
- Symbole für die Skills (`SkillDef.icon`) fehlen (AP7 oder AP8).
- Echte Effekte (AP1) statt der Platzhalter-Kreise.
- Balancing der Zahlen und der Erfahrungskurve (AP9).
