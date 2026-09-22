# Spiel JBR

Isometrisches 3D-Action-RPG im Stil von Diablo 4, gebaut mit **Godot 4.7.2** für den Windows-Desktop.
Nur Einzelspieler. Ziel für Version 0.1: 1 Klasse (Krieger), 1 Gebiet (Dorf und Katakomben), 1 Boss.

Der vollständige Plan steht in [docs/PLAN.md](docs/PLAN.md), die Regeln für die Mitarbeit in
[CONTRIBUTING.md](CONTRIBUTING.md), die Notizen je Arbeitspaket in [docs/pakete/](docs/pakete/).

## Spielen ohne Godot (Windows-Build laden)

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
| Linke Maustaste | Laufen und Angreifen (im Testraum: Markierung auf den Boden setzen) |
| W A S D | Laufen |
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
