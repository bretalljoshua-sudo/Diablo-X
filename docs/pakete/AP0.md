# AP0 – Projektgerüst und Verträge

Stand: 22.09.2026 · Godot 4.7.2 · GUT 9.7.1 · gdtoolkit 4.5.0

## Was gebaut ist

| Bereich | Wo |
|---|---|
| Godot-Projekt (Forward+, Jolt, Vulkan unter Windows, 1920 × 1080) | `project.godot`, Version in `.godot-version` |
| Ordnerstruktur aus Plan, Abschnitt 4 | leere Paketordner mit `.gitkeep` |
| Verträge aus Plan, Abschnitt 6 | `scripts/contracts/` |
| Autoloads `EventBus`, `Game`, `Rng`, `SaveService`, `Settings` | `autoload/` |
| Ersatz-Dienste `Combat`, `Stats`, `Loot`, `World` | `combat/`, `loot/`, `world/` |
| Einfache Kamera `CameraRig` mit `shake()` und `screen_to_ground()` | `graphics/camera_rig.gd` |
| Testraum mit Boden, Würfel, Säulen, Mondlicht und Fackel | `debug/test_room.tscn` |
| Testszenen-Starter `--scene=<name>`, `--list-scenes` | `main.tscn`, `main.gd` |
| Debug-Anzeige (FPS, Knoten, Draw Calls, Speicher, Szene, Seed), F3 | `debug/debug_overlay.gd` (Autoload `DebugOverlay`) |
| Screenshot-Werkzeug: F12 und `--screenshot=<datei>` | `debug/screenshot_tool.gd` (Autoload `Screenshot`) |
| Alle Eingabe-Aktionen für Version 0.1 | `project.godot`, Tabelle in `CONTRIBUTING.md` |
| GUT, Testbasis `SimTest` für Simulationstests | `addons/gut/`, `tests/sim/sim_test.gd` |
| 29 Tests (Verträge, Dienste, Rng, Speichern, Starter, Kamera, Testraum) | `tests/unit/`, `tests/sim/` |
| Lint, Tests, Export als Skripte für Cloud und CI | `tools/` |
| CI: Lint und Tests bei jedem Push, Windows-Export bei `main` und manuell | `.github/workflows/` |
| Git LFS vorbereitet (noch keine großen Dateien) | `.gitattributes` |
| README und Regeln für die Threads | `README.md`, `CONTRIBUTING.md` |

## Wie man es testet

```bash
tools/install_godot.sh
pip install "gdtoolkit==4.5.0"
tools/lint.sh
tools/run_tests.sh
tools/export_windows.sh    # optional, lädt einmalig rund 1,3 GB Exportvorlagen
```

Auf Joshuas PC: Windows-Build aus GitHub Actions laden (siehe README) und starten. Zu sehen ist der
Testraum: dunkler Steinboden, vier Säulen, ein sich drehender roter Würfel mit der Schrift
„Spiel JBR – Testraum“, warmes Fackellicht und bläuliches Mondlicht, oben links die Debug-Anzeige.
Ein Linksklick auf den Boden setzt eine weiße Kugel an die Stelle und lässt die Kamera kurz wackeln.

## Abweichungen vom Plan und Festlegungen

- **Zufallsstrom als `RandomNumberGenerator`:** Der Plan schreibt `rng: Rng`. `Rng` ist aber der Name
  des Autoloads und kann in Godot nicht zugleich ein Typ sein. `Loot.roll_drop()` bekommt deshalb einen
  `RandomNumberGenerator`, erzeugt über `Rng.make(seed)` oder `Rng.stream(&"loot", index)`.
- **Zusätzliche Vertragsklassen:** `AffixRoll` (gewürfeltes Affix mit Wert, für `ItemInstance.affixes`),
  `LootEntry` (Eintrag einer `LootTable`) und `LevelConfig` (Eingabe für `World.generate()`).
- **Zusätzliche Felder:** `SkillDef.attack_range` und `SkillDef.radius`, `LevelLayout.cells` für die
  GridMap, `ItemBase.grid_size` für das Inventar-Raster, `ItemInstance.display_name`.
- **Ersatz-Dienste liegen im Ordner des Besitzers**, nicht in `autoload/`: So ersetzt AP2, AP4 und AP6
  den Inhalt, ohne einen `contracts:`-Commit zu brauchen. Die Autoload-Liste bleibt gleich.
- **Ersatz-Konvention für Schaden:** Bis AP2 steht, zieht `Combat.apply_damage()` Leben über eine
  Methode `take_damage(amount: float) -> bool` am Ziel ab. AP2 darf das durch die `HealthComponent`
  ersetzen.
- **Skillbaum auf K statt S:** S ist bereits „Laufen nach unten“ (WASD).
- **Zusammenführen ohne Pull Requests:** Laut Vorgabe führen die Threads selbst nach `main` zusammen
  (fetch, rebase, push). Pull Requests nur auf Joshuas Wunsch. Das ersetzt die PR-Regeln aus dem Plan.
- **Plan unverändert** als `docs/PLAN.md` übernommen.

## Offen

- Start des Windows-Builds auf Joshuas PC ist noch nicht bestätigt (Teil der „Fertig, wenn“-Bedingung).
  In der Cloud geprüft: Export läuft durch, das exportierte Paket startet headless und lädt den Testraum.
- Kein Programm-Icon in der `.exe`: Das Setzen braucht `rcedit` unter Windows, deshalb
  `application/modify_resources=false`. Kann später auf dem PC oder mit Wine nachgeholt werden.
- Grafikstufen in `Settings.quality` sind nur angelegt, ihre Wirkung baut AP1.
