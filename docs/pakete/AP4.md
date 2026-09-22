# AP4 – Beute und Gegenstände

Stand: 22.09.2026 · reine Logik, komplett headless getestet

## Was gebaut ist

| Bereich | Wo |
|---|---|
| `Loot.roll_drop()` (echte Version statt Ersatz), `Loot.roll_gold()`, `Loot.drop_at()`, `Loot.get_table()` | `loot/loot_service.gd` |
| Würfeln von Seltenheit, Grundform, Affixen, Aspekt, einzigartigen Gegenständen | `loot/item_generator.gd` |
| Seltenheit nach Gewicht und Gegnerstufe | `loot/rarity_settings.gd`, Daten `data/loot_tables/rarity.tres` |
| Namensgenerator | `loot/name_generator.gd`, Bausteine `data/items/name_parts.tres` |
| Inventar als Raster mit Gold und Verkaufen | `loot/inventory.gd` (`Inventory`, Komponente an der Figur) |
| Ausrüsten mit Neuberechnung der Werte | `loot/equipment.gd` (`Equipment`, Komponente an der Figur) |
| Vergleich zweier Gegenstände | `loot/item_compare.gd` (`ItemCompare`) |
| Verkaufs- und Kaufpreis | `loot/item_value.gd` (`ItemValue`) |
| Texte: Stat-Namen, Affix-Zeilen, Tooltip, Farben je Seltenheit | `loot/item_text.gd` (`ItemText`) |
| Speichern und Laden (JSON) von Gegenständen, Inventar, Ausrüstung | `loot/item_serializer.gd` (`ItemSerializer`) |
| Alle Inhalte laden | `loot/item_database.gd` (`ItemDatabase.get_default()`) |
| Platzhalter: Beute am Boden, Aufsammeln per Klick | `loot/ground_item.tscn`, `loot/ground_item.gd` |
| Testszene | `debug/loot_test.tscn` |
| 56 neue Tests | `tests/unit/test_loot_*.gd`, `test_item_*.gd`, `test_inventory.gd`, `test_equipment.gd`, `tests/sim/test_loot_scene.gd` |

### Inhalte (alles `.tres`, neue Inhalte brauchen keinen Code)

- **18 Grundformen** in `data/items/`: je Platz eine Form ab Stufe 1 und bessere ab Stufe 4, 5 oder 7
  (`ItemBase.min_level`). Waffe: Rostiges Schwert, Kriegsaxt, Grabklinge. Ringe haben den
  Grundplatz `RING_1` und passen in beide Ringplätze.
- **25 Affixe** in `data/affixes/`, auf alle 14 Stats verteilt, jeweils mit erlaubten Plätzen.
  Der Bereich `min_value` bis `max_value` gilt für alle Stufen: Stufe 1 würfelt in der unteren
  Hälfte, Stufe 10 in der oberen. Anteile (Krit, Resistenzen, Angriffs­geschwindigkeit,
  Abklingzeit) stehen als `0.05` und werden als „5 %“ angezeigt.
- **6 legendäre Aspekte** in `data/aspects/` (siehe unten).
- **2 einzigartige Gegenstände** in `data/items/uniques/`: „Ahnenzorn“ (Kriegsaxt) und
  „Krone der Asche“ (Eisenhelm), feste Werte und eine eigene Kraft.
- **Beutetabellen** in `data/loot_tables/`: `normal`, `elite`, `boss`, `chest`.

| Tabelle | Gegenstände | Gold (Stufe 1) | Besonderheit |
|---|---|---|---|
| `normal` | 0 bis 1 | 2 bis 8 | |
| `elite` | 1 bis 2 | 10 bis 25 | Seltenheitszuschlag +75 % |
| `boss` | 3 bis 4 | 60 bis 120 | mindestens Selten, Zuschlag +100 % |
| `chest` | 1 bis 3 | 15 bis 40 | Zuschlag +25 % |

Gold wächst je Stufe über 1 um 25 %.

### Geplante Seltenheitsverteilung

| Stufe | Normal | Magisch | Selten | Legendär | Einzigartig |
|---|---|---|---|---|---|
| 1 | 70 % | 25 % | 4,5 % | 0,5 % | 0 % |
| 5 | 56,7 % | 29,4 % | 10,5 % | 2,7 % | 0,7 % |
| 10 | 40 % | 35 % | 18 % | 5,5 % | 1,5 % |

Dazwischen wird linear gemischt. Der Seltenheitszuschlag einer Tabelle (`rarity_bonus`)
multipliziert die Gewichte von Magisch bis Einzigartig. Affixe: Magisch 1 bis 2, Selten 3 bis 4,
Legendär 3 bis 4 plus Aspekt, Einzigartig feste Werte.

### Namen

Normal: Grundform („Kettenhemd“). Magisch: Grundform + Zusatz des stärksten Affixes
(„Kettenhemd der Wehr“). Selten: zusammengesetztes Wort („Grabeszorn“). Legendär: Grundform +
Aspektname („Kriegsaxt des Mahlstroms“). Einzigartig: fester Name.

## Schnittstellen für andere Pakete

- **AP3 (Gegner):** beim Tod `Loot.drop_at(def.loot_table, stufe, Rng.stream(&"loot", i), position, level_node)`.
  Das würfelt, legt `GroundItem`s ab und sendet `EventBus.loot_dropped` je Gegenstand.
  Wer nur würfeln will: `Loot.roll_drop()` und `Loot.roll_gold()`. Elite-Gegner nehmen `elite`.
- **AP2 (Spieler):** `Inventory` und `Equipment` als Kindknoten an die Spielerfigur hängen.
  Der Stats-Dienst rechnet `Equipment.get_bonus_stats()` (oder `apply_to(grundwerte)`) ein und
  hört auf `Equipment.stats_changed`. Wie das aussieht, zeigt `debug/loot_test_player.gd`.
  `GroundItem` sammelt beim Klick in `Inventory.find_on(Game.player)` ein. Der Weg zum
  Gegenstand (hinlaufen, dann aufheben) gehört zur Spielersteuerung.
- **AP5 (Skills):** `Equipment.get_aspects_for_tags(skill.tags)` liefert die Aspekte und
  einzigartigen Kräfte, die einen Skill verändern. Die Zahlen stehen in `AspectDef.params`.
  Alle Tags stehen im Katalog `data/aspects/skill_tags.tres` (`SkillTagCatalog`), ein Test prüft,
  dass jeder Aspekt nur Tags aus dem Katalog nutzt.
- **AP7 (UI):** Raster über `Inventory` (`get_items()`, `get_position_of()`, `can_place()`,
  `move_item()`, Signal `changed`), Ausrüstung über `Equipment.equip_from_inventory()` und
  `unequip_to_inventory()`. Tooltip: `ItemText.tooltip_lines()`, Vergleich:
  `ItemCompare.lines(angelegt, kandidat)` mit `better` für grün/rot, Farbe:
  `ItemText.rarity_color()`. Händler: `Inventory.sell_item()`, `ItemValue.buy_price()`.
- **AP1 (Grafik):** Lichtsäule und Klang auf `EventBus.loot_dropped`. Die Platzhalter-Szene
  `loot/ground_item.tscn` darf AP1 optisch ersetzen, solange Skript und Kollision bleiben.
- **AP9 (Speichern):** `ItemSerializer.inventory_to_dict()` / `equipment_to_dict()` und die
  `…_from_dict()`-Gegenstücke. Gespeichert werden ids, deshalb ids in `data/` nie umbenennen.

### Aspekte und Skill-Tags

| Aspekt | Tags | Wirkung (Parameter) |
|---|---|---|
| Aspekt des Mahlstroms | `whirlwind` | Wirbelsturm zieht Gegner an (`pull_radius` 5 m, `pull_strength` 2 m/s) |
| Aspekt der Erschütterung | `leap` | Sprung betäubt (`stun_duration` 1,5 s) |
| Aspekt des Blutdurstes | `core` | Kern-Skills heilen (`lifesteal_percent` 5) |
| Aspekt des Flammenschreis | `shout` | Schreie entfachen Feuerring (`duration` 4 s, `fire_damage_percent` 40) |
| Aspekt des Sturmlaufs | `charge` | Ansturm stärker (`damage_bonus_percent` 50, `knockback` 3 m) |
| Aspekt der Grausamkeit | `basic` | Basis-Skills mehr Wut (`resource_bonus_percent` 30) |
| Kraft: Ahnenzorn (einzigartig) | `ancients` | `extra_ancients` 1, `damage_bonus_percent` 25 |
| Kraft: Krone der Asche (einzigartig) | `whirlwind` | `burn_damage_percent` 30, `burn_duration` 3 s |

Tag-Katalog: Skills `strike` (Hieb), `cleave` (Spaltschlag), `whirlwind`, `war_cry`, `leap`,
`charge`, `ancients` (Zorn der Ahnen); Kategorien `basic`, `core`, `defensive`, `mobility`,
`ultimate`; Eigenschaften `shout`, `channeled`, `physical`, `fire`, `aoe`, `movement`.
Parameter mit `_percent` sind Prozentzahlen (40 = 40 %).

## Wie man es testet

```bash
tools/lint.sh
tools/run_tests.sh
godot --path . -- --scene=loot_test
```

Wichtige Tests: `test_loot_distribution.gd` (je 10.000 Drops auf Stufe 1, 5 und 10 gegen die
Tabelle oben, Toleranz 4 Standardabweichungen), `test_equipment.gd` (Ausrüsten verändert die
Werte, auch über den Stats-Dienst), `tests/sim/test_loot_scene.gd` (Aufsammeln und Anlegen in der
Testszene erhöht Schaden und Rüstung).

Testszene (`SpielJBR.exe --scene=loot_test`): Zu Beginn liegen drei Boss-Drops am Boden, farbig
nach Seltenheit mit Namensschild. Linksklick auf den Boden lässt Beute der aktuellen Tabelle
fallen, Linksklick auf Beute hebt sie auf und zeigt Tooltip und Vergleich. 1/2 Stufe −/+,
3 Tabelle wechseln, 4 simuliert 1.000 Drops und zeigt die Verteilung, I legt bessere Gegenstände
an, Q verkauft das Inventar. Oben links stehen Werte, Gold und Ausrüstung.

## Verträge geändert

- `ItemBase.min_level` (bessere Grundformen erst ab einer Stufe).
- `LootTable.min_rarity` und `LootTable.rarity_bonus` (Boss mindestens selten, Elite-Zuschlag).
- `PhysicsLayers.LOOT` und Ebene 5 „loot“ in `project.godot` für Beute am Boden.

## Festlegungen

- Eine Tabelle ohne Einträge (oder `null`) liefert genau einen Gegenstand aus allen Grundformen,
  damit der Signaturtest aus AP0 gültig bleibt.
- Gold ist kein Gegenstand: `roll_drop()` liefert nur Gegenstände, Gold kommt aus `roll_gold()`.
- Ablegen sendet `EventBus.player_equipped(slot, null)`.
- Inventar 10 × 6 Zellen; Waffen 1 × 3 oder 2 × 3, Brust 2 × 3, Rüstungsteile 2 × 2, Schmuck 1 × 1.
- `ItemCompare.score()` ist eine grobe Wertungszahl (Gewichte in `SCORE_WEIGHTS`), gut genug für
  „besser/schlechter“ und Auto-Ausrüsten in der Testszene. Feinabstimmung im Balancing (AP9).

## Offen

- Aspekte wirken erst, wenn AP5 die Parameter über die Tags auswertet.
- Stats-Dienst (AP2) muss `Equipment.get_bonus_stats()` einrechnen; bis dahin zeigt nur die
  Testszene die Wirkung.
- Beutefilter, Lichtsäule, Klang und schöneres Aussehen am Boden (AP1), Beschriftung nur mit Alt (AP7).
- Symbole (`ItemBase.icon`) und Modelle (`ItemBase.model`) fehlen noch (AP8).
- Balancing der Werte, Preise und Goldmengen (AP9).
