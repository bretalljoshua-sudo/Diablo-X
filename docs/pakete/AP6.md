# AP6 – Dungeon und Dorf

Stand: 22.09.2026 · fertig bis auf die Prüfung am PC

## Was gebaut ist

| Bereich | Wo |
|---|---|
| Dungeon-Generator: Räume aus Vorlagen wachsen als Baum, gerade Gänge, zusätzliche Schleifen | `world/dungeon_generator.gd` |
| 12 Raumvorlagen (gedreht und gespiegelt), darunter ein Bossraum | `data/world/rooms/*.tres`, Klasse `world/room_template.gd` |
| Ebenen-Einstellungen: Dorf, Ebene 1 (7 Räume), Ebene 2 (9 Räume), Bossraum | `data/world/levels/depth_<n>.tres` (`LevelConfig`) |
| Dorf „Aschental“ als feste Karte mit Händler, Truhe, Brunnen, Häusern und Gruft-Eingang | `data/world/village.tres`, `world/village_map.gd` |
| Wände, Ecken, Türöffnungen, Säulen, Treppen, Fackeln, Feuerschalen, Requisiten, Spawnpunkte je Raum | im Generator |
| Aufbau als zwei `GridMap` (Aufbau und Requisiten) mit Kollision auf Ebene `world` | `world/level_builder.gd` |
| Navigation zur Laufzeit gebacken, direkt aus den begehbaren Zellen | `LevelBuilder.bake_navigation()` |
| Platzhalter-Baukasten aus grauen Blöcken, Umschalten auf AP8 über den festen Pfad | `world/placeholder_kit.gd`, `world/world_kit.gd` |
| Spielwelt-Szene: baut Ebenen, hält die Spielerfigur über Wechsel hinweg, Stimmung je Thema | `world/level.tscn`, `world/level.gd` |
| Übergänge über Treppen und Gruft-Eingang, Ladebildschirm, Rückkehrportal im Bossraum | `world/exit_trigger.gd`, `world/loading_screen.gd`, `World.travel_to()` |
| Daten für die Minikarte (Bild mit einem Pixel pro Zelle, Umrechnung Welt ↔ Bild, Raum unter einer Position) | `world/minimap_data.gd` |
| Ersatzfigur zum Laufen (Kapsel, Klick oder WASD), solange AP2 keine Figur liefert | `world/placeholder_walker.gd` |
| Testszene mit Minikarte, Übersicht und Tasten für alle Ebenen | `debug/world_test.tscn` |
| Tests: Vorlagen, Drehungen, gleicher Seed, 1.000 Seeds erreichbar, Dorf, Minikarte, Aufbauzeit, Wege, Übergänge | `tests/unit/test_world_generator.gd`, `tests/sim/test_level_build.gd` |

„Fertig, wenn“ aus dem Plan:

- Gleicher Seed ergibt gleichen Dungeon: `test_same_seed_same_dungeon` (Zellen, Drehungen, Requisiten,
  Spawnpunkte, Ausgänge, Lichter, Räume, Start).
- Alle Räume erreichbar über 1.000 Seeds: `test_all_rooms_reachable_over_many_seeds` prüft per
  Flutfüllung vom Start, dass jede begehbare Zelle, jeder Ausgang, jeder Spawnpunkt und jeder Marker
  erreichbar ist (Ebenen 1, 2 und Bossraum gemischt).
- Aufbau einer Ebene unter 1 Sekunde: `test_build_is_fast_for_all_depths` (Generieren, GridMap,
  Navigation, Lichter). Gemessen in der Cloud: 11 bis 57 ms je Ebene.

## Wie man es testet

```bash
tools/run_tests.sh
godot --path . -- --scene=world_test                 # Ebene 1
godot --path . -- --scene=world_test --depth=0       # Dorf (2 = Ebene 2, 3 = Bossraum)
godot --path . -- --scene=world_test --overview --seed=7
SpielJBR.exe --scene=world_test                      # dasselbe im Windows-Build
```

Tasten in der Testszene: **0** Dorf, **1** und **2** Ebenen, **3** Bossraum, **N** neuer Dungeon,
**P** Portal im Bossraum öffnen, **O** Übersicht über die ganze Ebene, **M** oder **Tab** große
Minikarte, **Linksklick** oder **WASD** laufen. Wer auf eine Treppe oder in den Gruft-Eingang läuft,
wechselt mit Ladebildschirm die Ebene. Unten links stehen Seed, Anzahl Räume und Aufbauzeit.

## Für andere Pakete

- **Ebene wechseln:** `World.travel_to(depth)`. Aus dem Dorf in die Katakomben wird immer neu
  gewürfelt, innerhalb eines Durchlaufs bleiben die Ebenen gleich (Seed aus `World.run_seed`).
- **Signale:** `level_transition_started(target_depth)`, dann `level_unloading(layout)` (eigene Knoten
  wegräumen), dann `level_loaded(layout)`.
- **Gegner (AP3):** `layout.spawn_points` mit `layout.spawn_rooms` (Raum je Punkt, im Startraum und
  im Bossraum keine). Gegner als Kinder von `Level.get_active().actors` einsetzen, dann räumt der
  Wechsel sie automatisch weg. Navigation liegt auf der Standardkarte der Welt, Agentenradius 0,5 m.
- **Spielerfigur (AP2, AP9):** Die Level-Szene nimmt `Game.player`, sonst `player_scene`, sonst die
  Ersatzkapsel. Hat die Figur eine Methode `teleport(position)`, wird sie beim Wechsel benutzt.
  Ausgänge reagieren auf Körper in der Ebene `player`, die `Game.player` sind oder in der Gruppe
  `player` stehen.
- **Boss (AP9):** Marker `boss_spawn`, `boss_chest`, `boss_gate` (Türöffnung des Bossraums),
  `portal`, `boss_room_center`; `layout.boss_room` ist der Index des Bossraums. Nach dem Sieg
  `World.open_portal()` aufrufen, dann führt das Portal ins Dorf.
- **Dorf (AP7, AP9):** Marker `merchant` und `stash` für Händler und Truhe.
- **Minikarte (AP7):** `MinimapData.build_image(layout)`, `world_to_pixel()`, `room_at()`;
  `layout.rooms` und `layout.room_links` für Raumumrisse.
- **Licht und Stimmung (AP1):** Liegt unter `res://graphics/environments/<theme>.tres` ein
  `Environment` (Themen `catacombs`, `boss`, `village`), nimmt die Level-Szene dieses. Lichter baut
  `LevelBuilder.make_light()`, dort kann AP1 seine Licht-Vorlagen einsetzen.

## Geänderte Verträge

- `LevelLayout`: neue Felder `depth`, `theme`, `cell_size`, `cell_orientations`, `props`,
  `prop_orientations`, `rooms`, `room_links`, `spawn_rooms`, `boss_room`, `entrance`, `markers`.
- `EventBus`: neue Signale `level_unloading(layout)` und `level_transition_started(target_depth)`.

## Offen

- **Am PC ansehen:** Licht, Wandhöhe und Lesbarkeit der grauen Blöcke sind nur per Software-Rendering
  in der Cloud geprüft (Bilder sahen stimmig aus: Treppe an der Wand, Fackeln richtig gedreht).
- **Echter Baukasten:** kommt von AP8 unter `res://assets/world/world_kit.tres`. Danach Wandstücke
  und Drehungen im Bild prüfen.
- **Verdeckende Wände** vor der Figur ausblenden macht AP1.
- **Gänge sind gerade** und 4 m breit; Knicke und breitere Hallen wären eine spätere Erweiterung.
- **Seed im Dorf:** Das Dorf ist fest, `--seed` wirkt nur auf die Katakomben.

## Absprache mit AP8: Baukasten als MeshLibrary

### Pfade

| Was | Pfad | Paket |
|---|---|---|
| Echte MeshLibrary (Baukasten für Katakomben und Dorf) | `res://assets/world/world_kit.tres` | AP8 liefert |
| Platzhalter aus grauen Blöcken (wird im Code erzeugt) | `world/placeholder_kit.gd` | AP6 |

`world/` lädt die echte Bibliothek, sobald es die Datei gibt, sonst den Platzhalter. Die Zuordnung
läuft **über den Namen** des Items (`MeshLibrary.find_item_by_name()`), nicht über die Item-ID. AP8
darf die IDs also frei vergeben, die Namen müssen aber genau so heißen wie in der Tabelle unten.
Fehlt ein Name in der echten Bibliothek, nimmt `world/` für diese Zelle den grauen Platzhalter und
schreibt eine Warnung ins Log.

### Raster und Ausrichtung

- Eine Zelle ist **4 × 4 m** groß, Zellhöhe 4 m (`GridMap.cell_size = Vector3(4, 4, 4)`).
- `cell_center_x = true`, `cell_center_z = true`, `cell_center_y = false`: Der Ursprung eines Items
  liegt in der Mitte der Zelle **auf Bodenhöhe**. Die Oberkante des Bodens ist y = 0.
- Alles steht auf einer Ebene (y-Index 0). Requisiten liegen in einer zweiten `GridMap` mit gleichem
  Raster, darum darf eine Zelle Boden **und** eine Requisite haben.
- **Blickrichtung ist lokal +Z.** Bei Wänden zeigt +Z zur begehbaren Seite. `world/` dreht die
  Items in 90°-Schritten um die y-Achse.
- Wände sind ganze Zellen: Die Wandzelle liegt neben der Bodenzelle. Das sichtbare Wandstück sitzt
  an der Kante zur begehbaren Seite (lokal +Z, also bei z = +2 m), der Rest der Zelle darf leer
  bleiben.
- Jedes Item bringt seine Kollision mit (Wände, Säulen, Requisiten, die im Weg stehen). Böden
  brauchen eine flache Kollision, damit Figuren darauf stehen. Die Navigation backt `world/` selbst
  aus den Zellen, sie hängt nicht an den Meshes.
- Wandhöhe frei, Vorschlag 3 bis 4 m. Das Ausblenden verdeckender Wände macht AP1.
- Der Platzhalter füllt Wandzellen als ganze graue Blöcke (2,5 m hoch) mit heller Kante auf der
  begehbaren Seite, damit Drehfehler sofort auffallen.

### Zellnamen

Die Spalte „ID“ ist die ID, die `world/` intern und in `LevelLayout.cells` benutzt
(`world/world_tiles.gd`). Neue Namen werden nur **am Ende** angehängt.

**Katakomben, Aufbau** (Ebene `cells`)

| ID | Name | Was | Ausrichtung (lokal) |
|---|---|---|---|
| 0 | `floor` | Bodenplatte 4 × 4 m | beliebig, `world/` dreht zufällig |
| 1 | `floor_cracked` | Bodenplatte, gesprungen | beliebig |
| 2 | `floor_rubble` | Bodenplatte mit etwas Schutt, begehbar | beliebig |
| 3 | `wall` | Gerade Wand | begehbare Seite +Z |
| 4 | `wall_corner` | Innenecke eines Raums (Boden liegt nur schräg daneben) | Boden bei +X und +Z schräg |
| 5 | `wall_corner_outer` | Außenecke, die Wand ragt in den Raum | Boden bei +X und bei +Z |
| 6 | `wall_double` | Wand mit Boden auf beiden Seiten | Boden bei +Z und −Z |
| 7 | `wall_end` | Wandende (Boden auf drei Seiten) | Wand geht nach −Z weiter |
| 8 | `doorway` | Türöffnung (Bogen) zwischen Raum und Gang, begehbar | Durchgang entlang Z, Pfosten bei ±X |
| 9 | `pillar` | Säule im Raum, nicht begehbar | beliebig |
| 10 | `stairs_down` | Treppe nach unten (Ausgang zur nächsten Ebene), begehbar | Abgang nach −Z, man kommt von +Z |
| 11 | `stairs_up` | Treppe nach oben (Rückweg), begehbar | Aufgang nach −Z, man kommt von +Z |
| 12 | `floor_boss` | Boden des Bossraums (Ritualkreis o. Ä.), begehbar | beliebig |
| 13 | `portal` | Sockel für das Rückkehrportal ins Dorf, begehbar | beliebig |

**Requisiten** (Ebene `props`, eine pro Zelle)

| ID | Name | Was | Ausrichtung (lokal) |
|---|---|---|---|
| 20 | `prop_barrel` | Fässer | beliebig |
| 21 | `prop_crate` | Kisten | beliebig |
| 22 | `prop_bones` | Knochenhaufen, flach, begehbar | beliebig |
| 23 | `prop_candles` | Kerzengruppe, flach, begehbar | beliebig |
| 24 | `prop_coffin` | Sarkophag | Kopfende −Z |
| 25 | `prop_rubble` | Geröllhaufen | beliebig |
| 26 | `prop_table` | Tisch mit Kram | beliebig |
| 27 | `prop_banner` | Banner an der Wand | hängt an der Wand bei −Z |
| 28 | `torch_wall` | Wandfackel (nur Modell, das Licht setzt `world/`) | hängt an der Wand bei −Z |
| 29 | `brazier` | Feuerschale, freistehend (Licht setzt `world/`) | beliebig |
| 30 | `prop_chest` | Truhe, nur Deko (die Belohnungstruhe ist eine Szene von AP9) | Vorderseite +Z |
| 31 | `prop_cobweb` | Spinnweben in der Ecke, begehbar | Ecke bei −X und −Z |

**Dorf** (Ebene `cells` und `props`)

| ID | Name | Was | Ausrichtung (lokal) |
|---|---|---|---|
| 40 | `ground_grass` | Wiese, begehbar | beliebig |
| 41 | `ground_path` | Pflasterweg, begehbar | beliebig |
| 42 | `ground_dirt` | Erde, Matsch, begehbar | beliebig |
| 43 | `house_wall` | Hauswand mit Dachkante (Haus als Block aus Zellen), nicht begehbar | Außenseite +Z |
| 44 | `house_corner` | Hausecke | außen bei +X und +Z |
| 45 | `house_door` | Hauswand mit Tür (Deko, nicht betretbar) | Außenseite +Z |
| 46 | `fence` | Zaun, nicht begehbar | verläuft entlang X |
| 47 | `tree` | Baum, nicht begehbar | beliebig |
| 48 | `rock` | Felsen, Randbegrenzung, nicht begehbar | beliebig |
| 49 | `well` | Brunnen | beliebig |
| 50 | `lamp_post` | Laternenpfahl (Licht setzt `world/`) | beliebig |
| 51 | `market_stall` | Marktstand des Händlers | Vorderseite +Z |
| 52 | `crypt_entrance` | Eingang zu den Katakomben (Gruftportal), begehbar | Eingang bei +Z |
| 53 | `house_roof` | Dachfläche über dem Hausinneren, nicht begehbar | beliebig |

Händler, Truhe und Boss sind **Szenen** anderer Pakete. `world/` liefert dafür nur Positionen in
`LevelLayout.markers` (zum Beispiel `&"merchant"`, `&"stash"`, `&"boss_spawn"`, `&"boss_chest"`).
