# AP6 – Dungeon und Dorf

Stand: 22.09.2026 · in Arbeit

Dieses Dokument legt zuerst die **Absprache mit AP8** fest (Baukasten, Zellnamen, Pfad der
MeshLibrary). Der Rest folgt, wenn das Paket fertig ist.

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
