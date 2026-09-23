# Spiel JBR

Isometrisches 3D-Action-RPG im Stil von Diablo 4, gebaut mit **Godot 4.7.2** für den Windows-Desktop.
Nur Einzelspieler. Version 0.1: 1 Klasse (Krieger), 1 Gebiet (Dorf und Katakomben), 1 Boss.

Der vollständige Plan steht in [docs/PLAN.md](docs/PLAN.md), die Regeln für die Mitarbeit in
[CONTRIBUTING.md](CONTRIBUTING.md), die Notizen je Arbeitspaket in [docs/pakete/](docs/pakete/).

## Spielen

1. Unter **Releases** (rechts auf der Repo-Seite) die neueste Version öffnen, zum Beispiel
   `v0.1.0`, und `SpielJBR-v0.1.0-windows.zip` laden.
2. ZIP entpacken und `SpielJBR.exe` starten. Es erscheint der Titelbildschirm mit
   **Neues Spiel**, **Weiter** und **Beenden**.
3. Im Dorf steht die Händlerin Mira. Hinten im Dorf führt der Gruft-Eingang in die Katakomben:
   Ebene 1, Ebene 2 und die Gruft des Wächters. Nach dem Sieg bringt das Portal zurück ins Dorf.

Der Spielstand liegt in `%APPDATA%\Godot\app_userdata\Spiel JBR\savegame.json`, die
Einstellungen daneben in `settings.cfg`. Gespeichert wird automatisch (Ebenenwechsel,
Stufenaufstieg, Sieg, jede Minute, Beenden). **Weiter** lädt den Stand im Dorf. Wer neu anfangen
will, wählt **Neues Spiel** und bestätigt das Überschreiben.

## Neuester Entwicklungsstand (Windows-Build laden)

Bei jedem Push auf `main` baut GitHub automatisch einen Windows-Build.

1. Im Repo auf **Actions** gehen und links **Windows-Export** wählen.
2. Den obersten grünen Lauf öffnen.
3. Unten unter **Artifacts** auf `SpielJBR-windows-<commit>` klicken. Es lädt eine ZIP-Datei.
4. ZIP entpacken und `SpielJBR.exe` starten.

Hinweise:
- Windows zeigt beim ersten Start eventuell „Der Computer wurde durch Windows geschützt“, weil der Build
  nicht signiert ist. Dann auf **Weitere Informationen** und **Trotzdem ausführen** klicken.
- `SpielJBR.console.exe` startet dasselbe Spiel mit einem Konsolenfenster, in dem Fehlermeldungen stehen.
  Das hilft, wenn etwas nicht startet.
- Einen Build für einen beliebigen Stand gibt es über **Actions → Windows-Export → Run workflow**.
- Downloads bleiben 30 Tage verfügbar.

## Im Godot-Editor öffnen

1. [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) herunterladen
   (Standardversion, nicht .NET).
2. [Git LFS](https://git-lfs.com/) installieren, einmalig `git lfs install` ausführen.
3. Repo klonen: `git clone https://github.com/bretalljoshua-sudo/Diablo-X.git`
4. In Godot **Importieren** wählen und `project.godot` öffnen. **F5** startet das Spiel.

## Starten mit Optionen

Optionen stehen hinter dem Programmnamen, im Editor-Aufruf hinter `--`:

```
SpielJBR.exe                                    Titelbildschirm (normaler Start)
SpielJBR.exe --scene=boss_test                  direkt in den Bossraum (Stufe 6, ohne Speichern)
SpielJBR.exe --scene=res://encounters/game.tscn --bot --no-save
                                                ein Bot spielt das Spiel, zum Zuschauen
SpielJBR.exe --scene=test_room                  Testszene aus debug/ starten
SpielJBR.exe --list-scenes                      vorhandene Testszenen ausgeben
SpielJBR.exe --seed=12345                       festen Zufalls-Seed nutzen
SpielJBR.exe --screenshot=vorher.png            nach 90 Bildern Screenshot, dann beenden
godot --path . -- --scene=test_room             dasselbe aus dem Repo-Ordner
```

Screenshots landen in `%APPDATA%\Godot\app_userdata\Spiel JBR\screenshots\`, der genaue Pfad steht im Log.

## Tasten

Die komplette Belegung steht in `project.godot` (Abschnitt `[input]`) und in CONTRIBUTING.md.

| Taste | Wirkung |
|---|---|
| Linke Maustaste | Laufen, Hieb auf Gegner, Beute aufheben (gedrückt halten: weiterlaufen) |
| Rechte Maustaste | Spaltschlag |
| 1 bis 4 | Skills der Skillleiste |
| W A S D | Laufen |
| Leertaste | Ausweichrolle |
| Q | Heiltrank |
| I · K · M | Inventar · Skillbaum · Karte |
| Alt | Beschriftungen der Beute am Boden |
| Esc | Menü (Einstellungen, Speichern und zum Titel, Beenden) |
| Mausrad | Zoom |
| F3 | Debug-Anzeige (FPS, Knoten, Draw Calls) ein und aus |
| F12 | Screenshot |

## Entwickeln

```
tools/install_godot.sh          Godot 4.7.2 für Linux laden (Cloud und CI)
pip install "gdtoolkit==4.5.0"  Lint-Werkzeuge
tools/lint.sh [--fix]           Formatierung und Stil prüfen
tools/run_tests.sh              GUT-Tests und Rauchtest aller Testszenen, headless
tools/export_windows.sh         Windows-Build nach build/windows/
```

Die CI (GitHub Actions) führt bei jedem Push Lint und Tests aus, den Windows-Export bei Pushes auf `main`.
