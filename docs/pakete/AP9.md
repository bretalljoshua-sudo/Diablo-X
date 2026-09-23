# AP9 – Boss, Spielablauf, Speichern und Balancing

Stand: 23.09.2026 · Godot 4.7.2 · alles headless getestet, Bilder mit Software-Rendering.
Mit AP9 ist Version 0.1.0 spielbar: `SpielJBR.exe` ohne Parameter öffnet den Titelbildschirm.

## Was gebaut ist

| Bereich | Wo |
|---|---|
| Titelbildschirm: Neues Spiel (fragt vor dem Überschreiben), Weiter (mit Kurzinfo zum Stand), Beenden, Musik, 3D-Kulisse | `encounters/title_screen.tscn`, `title_screen.gd` |
| Spielszene, die alle Pakete verbindet: Dorf → Ebene 1 → Ebene 2 → Bossraum → Portal → Dorf | `encounters/game.tscn`, `game_session.gd` (`GameSession`) |
| Boss „Der Gruftwächter“ mit zwei Phasen | `encounters/boss/`, Daten `data/encounters/crypt_warden.tres` (`BossDef`) |
| Bossraum: Gitter schließt hinter dem Spieler, Belohnungstruhe, Rückkehrportal | `encounters/boss_arena.gd`, `boss_gate.gd`, `reward_chest.gd` |
| Tod und Wiederbeleben (am Eingang der Ebene oder im Dorf, 10 % Gold weg) | `encounters/death_screen.gd`, `GameSession.revive()` |
| Händlerin Mira im Dorf (Kaufen, Verkaufen über das Fenster aus AP7) | `encounters/village_merchant.gd` |
| Speichern und Laden mit Formatnummer | `encounters/save_game.gd` (`SaveGame`) über `SaveService` (AP0) |
| Schwierigkeitskurve bis Stufe 10 | `encounters/difficulty_curve.gd`, Daten `data/encounters/difficulty.tres` |
| Musik: Dorf, Katakomben, Bosskampf, mit Überblendung | `encounters/music_director.gd`, `assets/audio/music/*.wav` |
| Bot, der das ganze Spiel spielt | `debug/run_bot.gd` (`RunBot`, baut auf dem Arena-Bot von AP3 auf) |
| Testszene Bossraum (Stufe 6) | `debug/boss_test.tscn` |
| 20 neue Tests | `tests/unit/test_ap9_*.gd`, `tests/sim/test_ap9_*.gd` |

## Der Gruftwächter

- Grundwerte Stufe 1: 1400 Leben, 80 Rüstung, 22 Schaden, 30 % Feuerwiderstand. Je Stufe +320
  Leben, +15 Rüstung, +4,5 Schaden. Er ist eine Stufe über der Gegnerstufe des Bossraums
  (`level_bonus`), nicht wegstoßbar und 1,45-mal so groß wie ein Skelett.
- **Phase 1:** Aufschlag (lange Vorwarnung, 170 %, Rückstoß), Spaltschlag im 140°-Bogen,
  Knochenspeer auf Entfernung.
- **Phase 2 unter 50 % Leben:** Er brüllt 1,6 s lang (unverwundbar, Kamerawackeln, Effekt
  `slam`), greift 15 % schneller an, beschwört alle 13 s drei Skelette (höchstens 6) und legt alle
  6 s drei Feuerflächen: eine unter den Spieler, zwei daneben (Radius 1,8 m, Vorwarnung 1,3 s,
  35 % seines Schadens je Sekunde, dazu Brennen). Betäubungen hält er höchstens 0,6 s aus.
- `EventBus.boss_phase_changed(boss, phase)` bei jedem Wechsel, auch beim Zurücksetzen (Phase 1).
- Sieg: Tor auf, Truhe mit 2 Würfen aus `chest.tres` plus Gold, Portal ins Dorf leuchtet,
  `EventBus.run_completed(sekunden)`.
- Alle Zahlen stehen in `data/encounters/crypt_warden.tres` und können ohne Code geändert werden.

## Ablauf und Speichern

- Neues Spiel beginnt im Dorf auf Stufe 1. Der Durchlauf zählt ab der Gruft bis zum Sieg.
- Gespeichert wird bei jedem Ebenenwechsel, Stufenaufstieg, nach dem Sieg, jede Minute, beim
  Beenden (auch über das Fenster-X) und über „Speichern und zum Titel“ im Pausenmenü.
- Datei: `%APPDATA%\Godot\app_userdata\Spiel JBR\savegame.json` (Einstellungen daneben in
  `settings.cfg`). Inhalt: Klasse, Stufe, Erfahrung, Skillpunkte und Ränge, Skillleiste,
  Inventar, Ausrüstung, Gold, Tränke und Fortschritt (Durchläufe, Bestzeit, Bosssiege, Tode,
  Spielzeit). `SaveService` legt die Versionsnummer außen herum, `SaveGame.FORMAT` die des
  Inhalts; `SaveGame.migrate()` ist die Stelle für spätere Umbauten.
- „Weiter“ lädt den Stand und beginnt immer im Dorf.
- Tod: 10 % Gold weg, Bildschirm „Du bist gefallen“, Erwachen am Eingang der Ebene oder im Dorf.
  Stirbt man beim Boss, bekommt er wieder volles Leben und das Tor geht auf.

## Balancing

Gegnerstufe = Spielerstufe + Abstand der Ebene, mindestens die Untergrenze, höchstens 10:

| Ebene | Abstand | Untergrenze |
|---|---|---|
| 1 Katakomben | −1 | 1 |
| 2 Katakomben | 0 | 2 |
| 3 Bossraum | 0 (Boss +1) | 3 |

So wächst die Welt beim zweiten und dritten Durchlauf mit, bis Stufe 10. Gemessen mit dem Bot
(5 Durchläufe mit den Endwerten, Stufe 1 bis Boss):

| Wert | Bot |
|---|---|
| Dauer eines Durchlaufs | 7 bis 10 min |
| Stufe beim Boss | 5 bis 7 |
| Bosskampf | 50 s bis 2,5 min, tiefster Lebensstand 13 bis 63 % |
| Tode | 0 |

Der Bot läuft zielstrebig zur Treppe. Ein Mensch, der Räume absucht und Beute ansieht, sollte bei
10 bis 15 Minuten landen. Das muss Joshua am Bildschirm bestätigen.

Vorher war der Boss viel zu hart (bis zu 10 Tode). Geändert: Feuerflächen kleiner und
schwächer, Bot trinkt Tränke auch außerhalb seiner Kampfschleife.

## Musik

Von der Cloud aus war keine freie Musikquelle ohne Konto erreichbar (nur GitHub). Die drei Stücke
sind deshalb selbst erzeugt, mit `encounters/tools/compose_music.gd` (Zupfklänge, Flächen,
Glocken, Trommeln, Hall), und laufen nahtlos in Schleife. Sie sind CC0 wie der Rest. Ob sie
gefallen, muss Joshua hören; bessere Stücke lassen sich einfach unter demselben Namen in
`assets/audio/music/` ablegen.

## Kleine Eingriffe in andere Pakete

| Datei | Warum |
|---|---|
| `player/player.tscn` (AP2) | Wegpunkte liegen 0,5 m über dem Boden. Mit `path_height_offset = 0.5` und `path_desired_distance = 0.5` folgt die Figur dem Pfad wirklich. Vorher blieb Klick-Laufen stehen. `wall_min_slide_angle = 0` lässt sie an Kanten entlanggleiten statt festzuhängen. |
| `world/level_builder.gd` (AP6) | Das Navigationsnetz in Türzellen ist nur so breit wie die Öffnung zwischen den Pfosten. Vorher führten Wege durch die Pfosten. |
| `world/exit_trigger.gd` (AP6) | Die Sperre nach dem Laden läuft in Spielzeit, und wer beim Scharfschalten schon im Bereich steht, reist auch. |
| `assets/world/world_kit.tres`, `assets/tools/build_world_kit.gd` (AP8) | Der Gruft-Eingang im Dorf hat einen Boden. Vorher fiel man davor ins Leere. |
| `loot/loot_service.gd` (AP4) | Beute landet auf dem Navigationsnetz, nicht in Wänden, wo man sie nicht aufheben kann. |
| `autoload/settings.gd` (AP0, `contracts:`) | Die Debug-Anzeige ist für Spieler standardmäßig aus (F3 schaltet sie ein). |
| `main.gd`, `project.godot`, `default_bus_layout.tres`, `.github/workflows/export.yml` (`contracts:`) | Titelbildschirm als Start, Version 0.1.0, Busse „Music“ und „Effects“, GitHub-Release bei Tags `v*`. |

## Wie man es testet

- `SpielJBR.exe`: Titelbildschirm, Neues Spiel.
- `SpielJBR.exe --scene=boss_test`: direkt in den Bossraum auf Stufe 6, ohne zu speichern.
- `SpielJBR.exe --scene=res://encounters/game.tscn --bot --no-save`: der Bot spielt, man schaut
  zu. Weitere Schalter: `--start-depth=0..3`, `--level=1..10`, `--continue`, `--save-path=…`.
- Headless: `tools/run_tests.sh`. Der Test `test_ap9_full_run` startet einen zweiten Godot-Prozess
  mit `--fixed-fps 60`, lässt den Bot ab Stufe 1 bis zurück ins Dorf spielen (auf der Cloud etwa
  75 s) und lädt den Stand danach in einem dritten Prozess.

## Was Joshua prüfen sollte

1. **Tempo:** Laufen, Angriffe, Gegnerdichte.
2. **Wucht:** Fühlen sich Treffer, Spaltschlag und der Aufschlag des Bosses kräftig an?
3. **Schwierigkeit:** Ist der Gruftwächter beim ersten Versuch machbar, aber knapp?
4. **Dauer:** Wie lange dauert ein Durchlauf vom Dorf bis zum Sieg?
5. Musik und Titelbildschirm.

## Offen für später

- Feinschliff nach Joshuas Rückmeldung: Zahlen in `data/encounters/` und `data/skills/`.
- Die Händlerin verkauft nur Zufallsware aus der Truhentabelle, eigene Händlerware gibt es nicht.
- Beim Beenden im Headless-Betrieb meldet der Gegner-Pool (AP3) harmlose „material is null“-Fehler
  des Dummy-Renderers. Mit Grafik ist das nicht geprüft.
