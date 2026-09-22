# Mitarbeit

Mehrere Claude-Threads arbeiten parallel an diesem Repo, jeder an einem Arbeitspaket (AP) aus
[docs/PLAN.md](docs/PLAN.md). Diese Regeln sorgen dafür, dass sie nicht aneinander vorbeibauen.

## Kurzfassung

1. Nur in den eigenen Ordnern arbeiten (Tabelle unten).
2. Verträge (`scripts/contracts/`, `autoload/`, Hauptszene, `project.godot`) nur als eigener kleiner
   Commit mit Präfix `contracts:`.
3. Vor jedem Push nach `main`: `tools/lint.sh` und `tools/run_tests.sh` grün.
4. `main` ist immer spielbar.
5. Zum Abschluss `docs/pakete/AP<n>.md` schreiben.

## Arbeitsablauf

Jeder Thread arbeitet auf einem Branch `ap<n>-<kurzname>`, zum Beispiel `ap4-loot`. Gibt die Session
einen anderen Branch-Namen vor, gilt dieser.

```bash
# Einmalig einrichten (Cloud)
tools/install_godot.sh
pip install "gdtoolkit==4.5.0"

# Arbeiten
git switch -c ap4-loot origin/main
# … Code, Daten, Testszene, Tests …
tools/lint.sh --fix
tools/run_tests.sh

# Selbst nach main zusammenführen
git fetch origin main
git rebase origin/main
tools/lint.sh && tools/run_tests.sh
git push origin HEAD:main          # abgelehnt? fetch, rebase, Tests, erneut pushen
git push -u origin HEAD            # den eigenen Branch zusätzlich sichern
```

- Kleine Schritte, oft zusammenführen. Ein halbfertiges Feature darf nach `main`, wenn es nichts
  kaputt macht (zum Beispiel nur in der eigenen Testszene erreichbar).
- Pull Requests gibt es nur, wenn Joshua das ausdrücklich wünscht.
- Nie `main` force-pushen und nie fremde Commits umschreiben.
- Nach dem Push prüfen, dass die CI auf `main` grün bleibt. Wird sie durch den eigenen Push rot,
  sofort reparieren oder den Commit zurücknehmen (`git revert`).

## Ordnerbesitz

| Ordner | Paket |
|---|---|
| `autoload/`, `scripts/contracts/`, `main.tscn`, `main.gd`, `project.godot`, `.github/`, `tools/` | AP0 (Änderungen nur per `contracts:`-Commit) |
| `components/`, `player/`, `combat/` | AP2 Spieler und Kampf |
| `enemies/` | AP3 Gegner und KI |
| `loot/` | AP4 Beute |
| `skills/` | AP5 Skills und Krieger |
| `world/` | AP6 Dungeon und Dorf |
| `ui/` | AP7 UI und Inventar |
| `graphics/` | AP1 Grafik, Licht und Kamera |
| `assets/` | AP8 Assets und Animation |
| `encounters/` | AP9 Boss und Spielablauf |
| `data/<art>/` | das Paket, dem die Art gehört (items und affixes: AP4, skills: AP5, enemies: AP3, loot_tables: AP4) |
| `debug/<name>.tscn`, `tests/unit/`, `tests/sim/` | jedes Paket seine eigenen Dateien |

Jede Szene (`.tscn`) gehört genau einem Paket. Szenendateien lassen sich schlecht zusammenführen,
deshalb bearbeitet niemand die Szene eines anderen Pakets.

## Verträge

Gemeinsam genutzt werden:

- `scripts/contracts/`: `Enums`, `HitInfo`, `DamageResult`, `StatBlock`, `AffixDef`, `AffixRoll`,
  `AspectDef`, `ItemBase`, `ItemInstance`, `SkillDef`, `EnemyDef`, `LootEntry`, `LootTable`,
  `LevelConfig`, `LevelLayout`
- `autoload/`: `EventBus` (Signale), `Game` (Spielerfigur, Szenenwechsel), `Rng` (reproduzierbarer
  Zufall), `SaveService`, `Settings`
- Dienste mit fester Signatur (Autoloads):

| Dienst | Signatur | Datei | ersetzt durch |
|---|---|---|---|
| `Combat` | `apply_damage(hit: HitInfo) -> DamageResult` | `combat/combat_service.gd` | AP2 |
| `Stats` | `get_stat(entity: Node, stat: Enums.Stat) -> float` | `combat/stats_service.gd` | AP2 |
| `Loot` | `roll_drop(table: LootTable, level: int, rng: RandomNumberGenerator) -> Array[ItemInstance]` | `loot/loot_service.gd` | AP4 |
| `World` | `generate(p_seed: int, config: LevelConfig) -> LevelLayout` | `world/world_service.gd` | AP6 |
| `CameraRig` | `shake()`, `screen_to_ground()`, `get_active()` | `graphics/camera_rig.gd` | AP1 |

AP0 hat für jeden Dienst eine einfache **Ersatzversion** angelegt (Schaden ohne Rüstung, festes
Übungsschwert, flacher Testraum). Die Dateien liegen schon im Ordner des zuständigen Pakets: das Paket
ersetzt den Inhalt, die Signatur bleibt. `tests/unit/test_services.gd` prüft die Signaturen und muss
grün bleiben.

Regeln für Änderungen an Verträgen:
- Nur als eigener kleiner Commit mit Präfix `contracts:`, zum Beispiel
  `contracts: EventBus.item_sold hinzufügen`. Dieser Commit geht zuerst allein nach `main`,
  die eigentliche Arbeit folgt danach.
- Neue Signale, Felder, Klassen und Enum-Werte hinzufügen ist erlaubt. Enum-Werte nur **am Ende**
  anhängen, denn `.tres`-Dateien speichern die Zahl.
- Bestehende Signale, Felder und Funktionen umbenennen oder ihre Parameter ändern ist nicht erlaubt.
- Die Hauptszene (`main.tscn`, `main.gd`), `project.godot` und die Liste der Autoloads gelten
  ebenfalls als Vertrag.

## Testszenen

Jedes Paket liefert eine Testszene `debug/<name>.tscn` (oder `debug/<name>/<name>.tscn`).
Gestartet wird sie mit `--scene=<name>`:

```bash
godot --path . -- --scene=combat_test
SpielJBR.exe --scene=combat_test
```

`tools/run_tests.sh` startet jede Testszene automatisch headless für 180 Bilder (Rauchtest).
Skriptfehler dabei lassen die CI scheitern.

## Tests

- GUT 9.7.1 liegt in `addons/gut/`. Tests heißen `test_*.gd` und erben von `GutTest`.
- `tests/unit/`: reine Logik (Formeln, Daten, Generatoren).
- `tests/sim/`: Simulationstests, die Szenen headless durchspielen. Grundlage ist `SimTest`
  (`tests/sim/sim_test.gd`) mit `load_scene()`, `hold_action()` und `tap_action()`.
- Zufall immer über `Rng.make(seed)` oder `Rng.stream(&"zweck")`, damit Tests reproduzierbar sind.
- Die Cloud hat keine Grafikkarte: Godot läuft dort mit `--headless`. Rendering, Licht und Aussehen
  lassen sich nur auf Joshuas PC oder im Windows-Build beurteilen.

## Code-Stil

- GDScript mit statischen Typen (`var x: int`, `func f(a: float) -> void`).
- Bezeichner auf Englisch, Kommentare und Dokumente auf Deutsch.
- Formatierung mit `gdformat`, Stil mit `gdlint` (Konfiguration in `gdlintrc`); `tools/lint.sh --fix`
  korrigiert die Formatierung.
- Inhalte sind Daten: neue Gegner, Skills, Affixe als `.tres` in `data/`, nicht als Code.
- Pakete reden über `EventBus` und die Verträge, nie über innere Knoten anderer Pakete.

## Eingaben

Alle Aktionen für Version 0.1 sind in `project.godot` angelegt, damit niemand diese Datei nebenbei
ändern muss:

| Aktion | Taste | Aktion | Taste |
|---|---|---|---|
| `move_up`, `move_down`, `move_left`, `move_right` | W, S, A, D | `dodge` | Leertaste |
| `primary_action` | linke Maustaste | `potion` | Q |
| `secondary_action` | rechte Maustaste | `show_item_labels` | Alt |
| `skill_1` … `skill_4` | 1 bis 4 | `open_inventory` | I |
| `open_skills` | K (S ist schon Laufen) | `open_map` | M, Tab |
| `pause` | Esc | `toggle_debug_overlay` | F3 |
| `screenshot` | F12 | | |

## Große Dateien (Git LFS)

- Modelle, Texturen, Klänge und Schriften laufen über Git LFS (siehe `.gitattributes`).
  Vor dem ersten Commit solcher Dateien `git lfs install` ausführen.
- Das kostenlose Kontingent ist klein (1 GB Speicher). Nur Dateien einchecken, die das Spiel wirklich
  lädt; Blender-Quellen und Rohdaten bleiben außerhalb des Repos.
- Jede fremde Quelle mit Lizenz in `assets/CREDITS.md` eintragen.

## CI

| Workflow | Wann | Was |
|---|---|---|
| `CI` (`ci.yml`) | jeder Push | `tools/lint.sh`, `tools/run_tests.sh` |
| `Windows-Export` (`export.yml`) | Push auf `main`, manuell | Windows-Build als Download (Artifact) |

Die Godot-Version steht in `.godot-version` und gilt für CI, Werkzeuge und Editor gleichermaßen.

## Abschluss eines Pakets

Wenn die „Fertig, wenn“-Bedingung aus dem Plan erfüllt ist, schreibt der Thread
`docs/pakete/AP<n>.md`: was gebaut ist, wie man es testet, was offen ist und welche Verträge sich
geändert haben.
