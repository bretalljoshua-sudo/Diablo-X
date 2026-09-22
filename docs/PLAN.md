# Projekt „Spiel JBR“ – Plan für ein Action-RPG im Stil von Diablo 4

Stand: 22.09.2026 · Version 2 (angepasst an Joshuas Antworten: Godot 4, Desktop, hochwertige 3D-Grafik, nur Einzelspieler)

---

## 1. Kurzfassung

Wir bauen ein isometrisches 3D-Action-RPG mit **Godot 4** für den Windows-Desktop: dunkle Gothic-Stimmung, wuchtige Kämpfe, zufällig erzeugte Dungeons und Beute, die den Build spürbar verändert.

- **Version 0.1 (Vertical Slice):** 1 Klasse, 1 Gebiet, 1 Boss, dazu vollständige Loot-, Skill- und Stufensysteme.
- **Version 1.0:** 3 Klassen, 3 Gebiete, viele Gegnertypen, mehrere Bosse, Endgame-Schleife.

Die Arbeit für 0.1 ist in **10 Arbeitspakete** (AP0 bis AP9) geschnitten, die in **4 Wellen** laufen. Nach dem Gerüst arbeiten bis zu vier Threads gleichzeitig. Die meisten Pakete laufen in der Cloud (Godot ohne Bildschirm, nur Logik, Tests und Exporte). Zwei Pakete, bei denen man das Bild sehen muss (Grafik sowie Assets und Animation), laufen am besten **direkt auf Joshuas Gaming-PC** in einem Ordner, den er für Claude freigibt.

**Was wir vor dem Verteilen brauchen:** ein GitHub-Repository (gern privat). Ein rein lokales Git auf dem PC reicht nicht, weil die Cloud-Threads ihre Arbeit sonst nicht zusammenführen können. Joshua klont das Repo auf seinen PC, spielt dort im Godot-Editor oder lädt den fertigen Windows-Build aus GitHub herunter.

---

## 2. Entscheidungen

| Thema | Entscheidung | Quelle |
|---|---|---|
| Engine | Godot 4.7 (aktuell 4.7.2), Desktop-Export für Windows | Joshua |
| Grafik | 3D, hoher Anspruch: Forward+-Renderer mit dynamischem Licht, Nebel, Nachbearbeitung | Joshua |
| Umfang | 0.1 = 1 Klasse, 1 Gebiet, 1 Boss · 1.0 = 3 Klassen, 3 Gebiete, viele Gegner | Joshua |
| Mehrspieler | nein, nur Einzelspieler | Joshua |
| Repo | GitHub, privat; lokal auf Joshuas PC geklont | Joshua (GitHub ok), Name noch offen |
| Sprache im Code | GDScript mit statischen Typen, Bezeichner Englisch | Claude |
| Dokumente | Deutsch | Claude |
| Startklasse | Krieger (Nahkampf, Ressource „Wut“) | Claude |
| Steuerung | Maus (Klicken zum Laufen und Angreifen) wie Diablo am PC, dazu WASD; Controller ab 0.9 | Claude |
| Namen und Stil | eigene Namen, eigene Welt; wir übernehmen Mechaniken, nichts Geschütztes | Claude |

**Offen, aber erst später nötig:** Budget für gekaufte Grafik-Assets (Entscheidung vor Version 0.3, siehe Abschnitt 5).

---

## 3. Kernkonzept

### Spielgefühl
- **Wucht:** Trefferstopp (wenige Millisekunden Einfrieren), Rückstoß, Schadenszahlen, Kamerawackeln bei starken Schlägen, Blut- und Funkeneffekte, Gegner zerfallen oder fliegen weg.
- **Direktheit:** Eingaben reagieren sofort, Angriffe lassen sich durch die Ausweichrolle abbrechen.
- **Düstere Atmosphäre:** dunkle Welt, warme Lichtinseln (Fackeln, Feuer, Kerzen), Volumennebel, der Spieler trägt einen Lichtschein.
- **Beute-Kick:** seltene Gegenstände fallen mit Lichtsäule und eigenem Klang; legendäre sind schon aus der Ferne erkennbar.

### Kernschleife
```
Dungeon betreten → Gegnergruppen besiegen → Beute aufsammeln
      ↑                                              ↓
 schwierigere Dungeons  ←  stärker werden  ←  ausrüsten, Skills verbessern, aufsteigen
```
Ein Dungeon-Durchlauf dauert 10 bis 15 Minuten und endet mit einem Bosskampf und garantierter Beute.

### Was wir aus Diablo 4 übernehmen
- Isometrische Kamera mit leichter Neigung, Figur im Bildzentrum
- Skillleiste mit 6 Plätzen (linke und rechte Maustaste, Tasten 1 bis 4), Klassenressource
- Skilltypen: Basis (baut Ressource auf), Kern (verbraucht Ressource), Verteidigung, Mobilität, Ultimativ
- Seltenheitsstufen: Normal, Magisch, Selten, Legendär, Einzigartig
- Zufällige Affixe, legendäre „Aspekte“, die Skills verändern
- Heiltränke mit Ladungen, die sich im Kampf auffüllen
- Ausweichrolle mit Abklingzeit
- Elite-Gegner mit Zusatzeigenschaften (schnell, brennend, schildtragend, …)
- Dungeons mit Ziel und Bossraum, Dorf als sicherer Ort

### Bewusst weggelassen
Mehrspieler, Saisons, Shop, offene Welt ohne Ladebildschirme, Reittiere, Zwischensequenzen.

### Inhalt von Version 0.1
| Bereich | Umfang |
|---|---|
| Klasse | Krieger, Stufe 1 bis 10 |
| Skills | 7 aktive Skills, je eine Verbesserung |
| Gebiet | Dorf als Startpunkt (Händler, Truhe) und 1 Dungeon „Katakomben“ mit 2 zufällig erzeugten Ebenen und Bossraum |
| Gegner | 4 normale Typen, Elite-Varianten mit 5 Zusatzeigenschaften, 1 Boss mit 2 Phasen |
| Beute | 9 Ausrüstungsplätze, rund 25 Affixe, 6 legendäre Aspekte, 2 einzigartige Gegenstände, Gold |
| Systeme | Inventar, Ausrüsten, Vergleichs-Tooltip, Händler, Speichern, Grafikeinstellungen |

---

## 4. Technik

### Entscheidungen mit Begründung
| Thema | Wahl | Begründung |
|---|---|---|
| Engine | Godot 4.7, Renderer Forward+ | Kostenlos, offen, starker 3D-Renderer; läuft ohne Bildschirm in der Cloud für Tests und Exporte (geprüft mit 4.5 am 22.09.2026) |
| Skriptsprache | GDScript, streng typisiert | Braucht kein .NET, beste Dokumentation, schnelle Iteration; Leistung reicht für ein ARPG. Heiße Stellen später bei Bedarf in C++ (GDExtension) |
| Physik | Jolt (in Godot eingebaut) | Stabil und schnell; genutzt nur für Kollision, nicht für Simulation |
| Figuren | `CharacterBody3D` für Spieler und Gegner | Standardweg in Godot, einfache Kollision mit Wänden |
| Wegfindung | `NavigationRegion3D`, zur Laufzeit gebacken, `NavigationAgent3D` mit Ausweichen | Funktioniert mit erzeugten Dungeons, Gegner laufen nicht ineinander |
| Dungeons | `GridMap` mit modularem Baukasten plus handgebaute Raumvorlagen | Schnell, speichersparend, passt zu Baukasten-Assets |
| Daten | eigene `Resource`-Klassen (`.tres`) für Gegenstände, Affixe, Skills, Gegner, Beutetabellen | Inhalte ohne Codeänderung, im Editor bearbeitbar, als Text versionierbar |
| Kommunikation | Autoload `EventBus` mit typisierten Signalen | Pakete kennen sich nicht direkt, weniger Konflikte beim parallelen Arbeiten |
| Zufall | eigener `Rng`-Dienst mit Seed je Dungeon und je Beutewurf | Dungeons und Beute reproduzierbar, Fehler nachstellbar |
| UI | Godot `Control`-Knoten mit eigenem Theme | Eingebaut, gut für Inventar, Tooltips und Menüs |
| Animation | `AnimationTree` mit Zustandsautomat; Trefferzeitpunkte über Methodenspuren | Saubere Übergänge, Treffer genau im Schlagmoment |
| Tests | GUT (Godot Unit Test) für Logik; Simulationstests, die Szenen headless mit einem Eingabe-Bot durchspielen | Beides läuft in der Cloud und in der CI |
| Codequalität | gdtoolkit (`gdlint`, `gdformat`) | Einheitlicher Code aus vielen Threads |
| CI | GitHub Actions: Lint, Tests headless, Windows-Export als Download | Jeder Stand ist als Build spielbar, ohne dass Joshua etwas kompilieren muss |
| Große Dateien | Git LFS für Modelle, Texturen und Klänge | Repo bleibt schnell; Kontingent im Blick behalten (GitHub: 1 GB frei) |

### Grafik: wie wir auf „richtig nice“ kommen
Das Aussehen entsteht in diesem Genre vor allem durch Licht und Nachbearbeitung, erst danach durch die Modelle.
- **Licht:** wenige, starke Lichtquellen mit Schatten (Fackeln, Feuerstellen), sonst schattenlose Fülllichter; der Spieler trägt ein weiches Licht. Globale Beleuchtung über SDFGI (funktioniert mit erzeugten Dungeons), SSAO und SSIL.
- **Atmosphäre:** Volumennebel mit Lichtstrahlen, Staubpartikel, Farbkorrektur (Farb-LUT), Tone Mapping AgX, Glow für Magie und Beute.
- **Oberflächen:** PBR-Materialien, nasse Böden mit Reflexionen (SSR), Decals für Blut, Brandspuren und Risse.
- **Effekte:** GPU-Partikel für Treffer, Blut, Funken, Feuer, Skill-Effekte; Shader für Auflösen beim Tod und Treffer-Aufblitzen.
- **Leistung:** Ziel 60 FPS in 1440p auf Joshuas PC mit „Hoch“; Grafikstufen Niedrig bis Ultra im Menü. Objekt-Pools für Gegner und Effekte, Verdeckungs-Culling, begrenzte Anzahl Schatten-Lichter.

### Architektur
```
Autoloads (immer da):  EventBus · Game (Zustand, Spielablauf) · Rng · SaveService · Settings
                            ▲ Signale              ▲ Dienste
─────────────────────────────┼──────────────────────┼──────────────────────────────
Szenen und Komponenten:
  Player (CharacterBody3D)            Enemy (CharacterBody3D)
   ├─ StatsComponent                   ├─ StatsComponent
   ├─ HealthComponent                  ├─ HealthComponent
   ├─ HurtboxComponent (Area3D)        ├─ HurtboxComponent
   ├─ SkillUser                        ├─ AIBrain (Zustandsautomat)
   ├─ Equipment / Inventory            ├─ LootDropper
   └─ Model + AnimationTree            └─ Model + AnimationTree
  Level (erzeugt aus LevelLayout)  ·  HUD / Fenster (Control)  ·  CameraRig
```
Grundregeln:
1. **Komponenten statt Vererbungsketten.** Leben, Werte, Treffer usw. sind kleine Knoten, die man an jede Figur hängt.
2. **Pakete reden über `EventBus` und die gemeinsamen Klassen in `scripts/contracts/`**, nie über die inneren Knoten anderer Pakete.
3. **Inhalte sind Daten.** Ein neuer Gegner, Skill oder Affix ist eine neue `.tres`-Datei, kein neuer Code.
4. **Jede Szene gehört genau einem Paket.** Szenendateien (`.tscn`) lassen sich schlecht zusammenführen; die Hauptszene ändern wir nur in kleinen, eigenen PRs.

### Ordnerstruktur
```
/
├─ project.godot
├─ addons/            GUT und weitere Plugins
├─ autoload/          EventBus, Game, Rng, SaveService, Settings        (AP0)
├─ scripts/contracts/ gemeinsame Klassen und Resource-Typen             (AP0, Änderungen nur per eigenem PR)
├─ components/        Health, Stats, Hitbox, Hurtbox, …                 (AP2)
├─ player/            Spielerfigur, Steuerung, Ausweichen               (AP2)
├─ combat/            Schadensberechnung, Statuseffekte                 (AP2)
├─ enemies/           Gegnerszenen, KI, Spawns, Elite-Eigenschaften     (AP3)
├─ loot/              Gegenstandserzeugung, Affixe, Drops, Inventar     (AP4)
├─ skills/            Skill-System, Krieger-Skills, Stufen              (AP5)
├─ world/             Dungeon-Generator, Dorf, Übergänge                (AP6)
├─ ui/                HUD, Inventar, Tooltips, Menüs, Theme             (AP7)
├─ graphics/          Environment, Kamera, Materialien, Effekte, Shader (AP1)
├─ assets/            Modelle, Animationen, Texturen, Klänge (Git LFS)  (AP8)
├─ encounters/        Boss, Spielablauf                                 (AP9)
├─ data/              .tres-Inhalte: items/, affixes/, skills/, enemies/, loot_tables/
├─ tests/unit/        GUT-Tests je Paket
├─ tests/sim/         Simulationstests (Bot spielt headless)
├─ debug/             Testszenen je Paket, Debug-Anzeige, Screenshot-Werkzeug
├─ docs/              dieser Plan, Paketnotizen, Balancing
└─ .github/workflows/ ci.yml, export.yml
```

### Was in der Cloud geht und was auf den PC gehört
| In der Cloud (headless) | Auf Joshuas PC (mit Grafikkarte) |
|---|---|
| Spiellogik, Daten, Szenen als Textdateien schreiben | Licht, Nebel, Materialien und Effekte beurteilen und feinjustieren |
| Unit-Tests und Simulationstests ausführen | Animationen und Spielgefühl prüfen |
| Windows-Build exportieren | Screenshots erzeugen und vergleichen |
| CI pflegen | Assets aus Quellen laden, die ein Konto brauchen |

Claude kann in einem Ordner auf Joshuas PC arbeiten, wenn er diesen Ordner in der Claude-Desktop-App freigibt oder dort `claude remote-control` startet. Dann laufen AP1 und AP8 direkt auf dem PC, inklusive Screenshots zum Prüfen. Ohne das schreiben die Cloud-Threads auch diese Pakete, und Joshua schaut sich jeden Stand im Build an.

---

## 5. Asset-Strategie

**Stufe A, ab sofort (kostenlos, CC0):**
- Dungeon-Baukasten, Requisiten, Figuren: KayKit (Dungeon Remastered, Adventurers, Skeletons) und Quaternius (Figuren, Tiere, Universal Animation Library)
- Texturen und Umgebungslicht: Poly Haven, ambientCG
- Klänge: freie Pakete (zum Beispiel Kenney, Sonniss GDC-Bundles), Musik CC0 oder CC-BY mit Namensnennung
- Stil: die Pakete sind eher stilisiert; dunkle Farbkorrektur, starkes Licht und eigene Materialien machen daraus einen düsteren Look

**Stufe B, vor Version 0.3 zu entscheiden:**
- Für einen deutlich realistischeren Look gekaufte Pakete (zum Beispiel von Fab, Synty oder itch.io), jeweils Lizenz für Godot prüfen
- Oder eine eigene Pipeline mit Blender für Anpassungen

**Pipeline:** Quelle → Blender (optional) → glTF 2.0 (`.glb`) → Godot-Import mit festen Import-Einstellungen. Alle Figuren nutzen ein gemeinsames Skelett, damit Animationen austauschbar sind. Jede Quelle mit Lizenz steht in `assets/CREDITS.md`.

---

## 6. Gemeinsame Schnittstellen (`scripts/contracts/`, `autoload/event_bus.gd`)

AP0 legt diese erste Fassung an. Skizze:

```gdscript
# autoload/event_bus.gd
extends Node
signal damage_dealt(hit: HitInfo, result: DamageResult)
signal entity_died(entity: Node3D, killer: Node3D)
signal entity_spawned(entity: Node3D)
signal loot_dropped(item: ItemInstance, position: Vector3)
signal loot_picked_up(item: ItemInstance)
signal gold_changed(total: int, delta: int)
signal skill_cast(caster: Node3D, skill: SkillDef, target_position: Vector3)
signal resource_changed(current: float, maximum: float)
signal player_level_up(level: int)
signal player_equipped(slot: Enums.Slot, item: ItemInstance)
signal level_loaded(layout: LevelLayout)
signal boss_phase_changed(boss: Node3D, phase: int)
signal run_completed(duration_sec: float)
```

```gdscript
# scripts/contracts/enums.gd
class_name Enums
enum Stat { MAX_LIFE, ARMOR, DAMAGE, ATTACK_SPEED, CRIT_CHANCE, CRIT_DAMAGE, MOVE_SPEED,
            LIFE_ON_HIT, RESOURCE_MAX, RESOURCE_REGEN, COOLDOWN_REDUCTION,
            FIRE_RESIST, COLD_RESIST, POISON_RESIST }
enum DamageType { PHYSICAL, FIRE, COLD, POISON }
enum Rarity { NORMAL, MAGIC, RARE, LEGENDARY, UNIQUE }
enum Slot { HELM, CHEST, GLOVES, PANTS, BOOTS, WEAPON, AMULET, RING_1, RING_2 }
enum Faction { PLAYER, ENEMY, NEUTRAL }
enum SkillCategory { BASIC, CORE, DEFENSIVE, MOBILITY, ULTIMATE }
enum Targeting { MELEE_ARC, SELF_AOE, GROUND_TARGET, PROJECTILE, DASH, CHANNEL }
```

```gdscript
# scripts/contracts/*.gd  (jeweils class_name, Resource oder RefCounted)
class_name HitInfo extends RefCounted          # Schadensanfrage
  var source: Node3D; var target: Node3D; var base: float
  var type: Enums.DamageType; var skill: SkillDef; var can_crit := true; var knockback := 0.0
class_name DamageResult extends RefCounted
  var amount: float; var crit: bool; var killed: bool

class_name StatBlock extends Resource           # Stat → Wert, addierbar
class_name AffixDef extends Resource            # id, stat, min, max, erlaubte Slots, Gewicht
class_name AspectDef extends Resource           # id, Beschreibung, betroffene Skill-Tags, Parameter
class_name ItemBase extends Resource            # id, Name, Slot, Grundwerte, Modell
class_name ItemInstance extends Resource        # uid, base, rarity, item_level, affixes[], aspect, unique
class_name SkillDef extends Resource            # id, Kategorie, Kosten, Aufbau, Abklingzeit, Zielart,
                                                # Schadensfaktor, Schadensart, Tags, Animation, Effekt
class_name EnemyDef extends Resource            # id, Szene, Werte je Stufe, Verhalten, Beutetabelle, EP
class_name LootTable extends Resource           # Einträge mit Gewicht, Gold-Bereich
class_name LevelLayout extends Resource         # seed, player_start, spawn_points[], exits[], lights[], bounds
```

Dienste, die Pakete anbieten (als Autoload oder statische Funktionen):
- `Combat.apply_damage(hit: HitInfo) -> DamageResult` (AP2)
- `Stats.get_stat(entity, stat) -> float` (AP2, gespeist von AP4 und AP5)
- `Loot.roll_drop(table: LootTable, level: int, rng: Rng) -> Array[ItemInstance]` (AP4)
- `World.generate(seed: int, config) -> LevelLayout` (AP6)

Regeln:
- Jedes Paket darf die Verträge nutzen, aber nicht nebenbei ändern. Änderungen sind ein eigener kleiner PR mit dem Titelpräfix `contracts:`.
- Neue Signale hinzufügen ist erlaubt; bestehende umbenennen nicht.
- AP0 liefert zu jedem Dienst eine einfache Ersatzversion (Schaden ohne Rüstung, fester Beutegegenstand, flacher Testraum). So kann jeder Thread sofort loslegen.

---

## 7. Arbeitspakete für Version 0.1

Jedes Paket liefert eine eigene **Testszene** in `debug/`, GUT-Tests für seine Logik, eine Notiz in `docs/pakete/AP<n>.md` und PRs gegen `main`. Branch-Namen: `ap<n>-<kurzname>`.

### AP0 – Projektgerüst und Verträge · Cloud
- **Ziel:** Ein lauffähiges Grundprojekt, auf dem alle anderen aufbauen.
- **Liefert:** Godot-4.7-Projekt mit Ordnerstruktur, Autoloads, Verträgen aus Abschnitt 6 und Ersatz-Diensten; GUT und gdtoolkit; CI mit Lint, Tests und Windows-Export als Download; `.gitattributes` für Git LFS; einfache Kamera, Testraum mit Boden und Würfel; Testszenen-Starter (`--scene=combat_test`), Debug-Anzeige (FPS, Knotenzahl), Screenshot-Werkzeug für den PC; `README.md` (Spiel starten, Build laden) und `CONTRIBUTING.md` mit den Regeln aus diesem Plan.
- **Abhängigkeiten:** keine. **Blockiert:** alle anderen.
- **Fertig, wenn:** CI ist grün, der Windows-Build startet auf Joshuas PC und zeigt den Testraum.

### AP1 – Grafik, Licht und Kamera · PC empfohlen
- **Ziel:** Die düstere, hochwertige Optik.
- **Liefert:** Kamera-Rig (fester isometrischer Winkel, weiches Folgen, Zoom, Wackeln), `WorldEnvironment`-Voreinstellungen für Dorf, Dungeon und Bossraum, Lichtregeln und Licht-Vorlagen (Fackel, Feuerstelle, Spielerlicht), Materialbibliothek, Effekt-Bibliothek (Treffer, Blut, Funken, Auflösen beim Tod, Beute-Lichtsäule), Schadenszahlen, Grafikstufen Niedrig bis Ultra, Leistungsprüfung.
- **Schnittstellen:** hört auf `damage_dealt`, `entity_died`, `loot_dropped`, `skill_cast`, `level_loaded`; bietet `CameraRig.shake()`, `CameraRig.screen_to_ground()`, `Vfx.spawn(key, position)`.
- **Abhängigkeiten:** AP0; profitiert von AP8 (echte Modelle).
- **Fertig, wenn:** Screenshot-Vergleich vorher/nachher überzeugt Joshua, 60 FPS in 1440p auf „Hoch“ mit 50 Gegnern.

### AP2 – Spieler, Steuerung und Kampfkern · Cloud
- **Ziel:** Laufen und Zuschlagen fühlen sich direkt und wuchtig an.
- **Liefert:** Spielerfigur, Klicken zum Laufen (Wegfindung), Halten zum Folgen, WASD, Ausweichrolle mit kurzer Unverwundbarkeit, Zielauswahl unter der Maus, Standardangriff, Komponenten (Health, Stats, Hitbox, Hurtbox), `Combat.apply_damage` (Rüstung, Resistenzen, kritische Treffer), Trefferstopp, Rückstoß, Tod, Heiltrank mit Ladungen, Statuseffekte (Verlangsamung, Brennen, Betäubung), `Stats` mit Grundwert + Ausrüstung + Effekte.
- **Schnittstellen:** sendet `damage_dealt`, `entity_died`; nutzt `screen_to_ground` (bis AP1 fertig: eigene einfache Version in AP0).
- **Abhängigkeiten:** AP0.
- **Fertig, wenn:** In der Testszene läuft der Spieler um Hindernisse und besiegt Trainingspuppen; Tests für Schadensformel und Werte sind grün.

### AP3 – Gegner und KI · Cloud
- **Ziel:** Gegner, die in Gruppen angreifen, sich unterschiedlich spielen und fair lesbar sind.
- **Liefert:** KI als Zustandsautomat (Ruhen, Bemerken, Verfolgen, Angreifen, Erholen), Angriffe mit sichtbarer Vorwarnung, 4 Gegnertypen als `EnemyDef`: Skelett-Schwarm, schwerer Ghul, Skelett-Bogenschütze, Kultist-Beschwörer; Gruppen-Spawns, Elite-Eigenschaften (schnell, brennend, schildtragend, teleportierend, vampirisch), Objekt-Pool, Beute und Erfahrung beim Tod.
- **Schnittstellen:** nutzt `Combat`, `Loot`, `Rng`, Navigation; sendet `entity_spawned`, `entity_died`, `loot_dropped`.
- **Abhängigkeiten:** AP0, AP2; profitiert von AP6 (echte Dungeons).
- **Fertig, wenn:** Simulationstest: Bot-Spieler besteht die Arena; 60 aktive Gegner kosten unter 3 ms pro Physik-Takt (headless gemessen).

### AP4 – Beute und Gegenstände · Cloud
- **Ziel:** Beute, die spannend ist und Entscheidungen erzeugt.
- **Liefert:** Basisgegenstände je Platz, Seltenheit nach Gewicht und Gegnerstufe, Affix-Pools (rund 25 Affixe), 6 Aspekte (zum Beispiel „Wirbelsturm zieht Gegner an“), 2 einzigartige Gegenstände, Namensgenerator, Gold, Beutetabellen, Inventar-Datenmodell (Raster), Ausrüsten mit Neuberechnung der Werte, Vergleich zweier Gegenstände, Verkaufswert.
- **Schnittstellen:** bietet `Loot.roll_drop`, `Inventory`, `Equipment.equip()`, `ItemCompare`; sendet `loot_picked_up`, `player_equipped`, `gold_changed`; Aspekte wirken über Skill-Tags auf AP5.
- **Abhängigkeiten:** AP0. Reine Logik, komplett headless testbar.
- **Fertig, wenn:** 10.000 simulierte Drops treffen die geplante Seltenheitsverteilung (Test), Ausrüsten verändert die Werte nachweisbar.

### AP5 – Skills und Klasse Krieger · Cloud
- **Ziel:** Ein Krieger mit spürbar unterschiedlichen Spielweisen.
- **Liefert:** Skill-System (Abklingzeit, Kosten, Wut aufbauen und verbrauchen, Zielarten), 7 Skills: Hieb (Basis), Spaltschlag (Kern), Wirbelsturm (Kern, kanalisiert), Kriegsschrei (Verteidigung), Sprung (Mobilität), Ansturm (Mobilität), Zorn der Ahnen (Ultimativ); je eine Verbesserung; Erfahrung, Stufen 1 bis 10, Skillpunkte, Anbindung der Aspekte über Tags.
- **Schnittstellen:** nutzt `Combat`, `Stats`, `CameraRig`; sendet `skill_cast`, `resource_changed`, `player_level_up`.
- **Abhängigkeiten:** AP0, AP2.
- **Fertig, wenn:** Alle 7 Skills funktionieren in der Testszene (Simulationstest je Skill), Stufenaufstieg vergibt Punkte, zwei Aspekte verändern Skills nachweisbar.

### AP6 – Dungeon und Dorf · Cloud
- **Ziel:** Jeder Dungeon-Besuch fühlt sich neu an und bleibt gut lesbar.
- **Liefert:** Generator aus Raumvorlagen (Räume und Gänge auf einem Raster, verbunden über einen Graphen), Aufbau per `GridMap`, Navigation zur Laufzeit backen, Spawnpunkte, Lichter, Requisiten, Ausgänge; 2 Ebenen plus Bossraum; das Dorf als feste Karte; Übergänge mit Ladebildschirm; Daten für die Minikarte.
- **Schnittstellen:** `World.generate()` liefert `LevelLayout`; sendet `level_loaded`.
- **Abhängigkeiten:** AP0; nutzt den Baukasten aus AP8 (bis dahin graue Blöcke).
- **Fertig, wenn:** Gleicher Seed ergibt gleichen Dungeon (Test), alle Räume erreichbar (Test über 1.000 Seeds), Aufbau einer Ebene unter 1 Sekunde.

### AP7 – UI und Inventar · Cloud (Feinschliff am PC)
- **Ziel:** Übersichtliche Oberfläche im Stil eines düsteren ARPG.
- **Liefert:** eigenes Theme, HUD (Lebenskugel, Wut-Kugel, Tränke, Skillleiste mit Abklingzeiten, Erfahrungsbalken), Lebensbalken über Gegnern, Bossbalken, Inventar-Fenster, Ausrüstung mit Figurvorschau, Tooltips mit farbigem Vergleich, Skillbaum, Händler, Minikarte, Pausenmenü mit Grafik-, Ton- und Steuerungseinstellungen, Beschriftungen am Boden (Alt), Tastenkürzel (I, S, M, Esc).
- **Schnittstellen:** liest Zustand über `EventBus`; ruft `Equipment`, Skillpunkte und Händler über AP4 und AP5 auf.
- **Abhängigkeiten:** AP0; echte Inhalte aus AP4 und AP5 (bis dahin Beispieldaten).
- **Fertig, wenn:** Ein kompletter Ausrüstungswechsel und Skillpunkt-Verteilung klappen mit Maus und Tastatur.

### AP8 – Assets und Animation · PC empfohlen
- **Ziel:** Echte Modelle und flüssige Animationen statt Platzhaltern.
- **Liefert:** Import der CC0-Pakete aus Abschnitt 5 mit festen Import-Einstellungen, gemeinsames Skelett und Animations-Retargeting, `AnimationTree` für Spieler und die 4 Gegnertypen (Laufen, Angriffe, Treffer, Tod, Ausweichen), Trefferzeitpunkte als Methodenspuren, Dungeon-Baukasten als `MeshLibrary` für AP6, Requisiten-Szenen, `assets/CREDITS.md`, Klänge für Treffer, Schritte und Beute.
- **Schnittstellen:** liefert Modelle unter festen Namen (`assets/characters/warrior.tscn` usw.) und die `MeshLibrary`; AP2, AP3 und AP6 tauschen nur noch die Szene aus.
- **Abhängigkeiten:** AP0.
- **Fertig, wenn:** Krieger und alle 4 Gegner sind animiert im Spiel, der Dungeon nutzt den Baukasten.

### AP9 – Boss, Spielablauf, Speichern und Balancing · Cloud + PC
- **Ziel:** Aus den Bausteinen wird eine runde Spielrunde.
- **Liefert:** Boss „Der Gruftwächter“ mit 2 Phasen (ab 50 % Leben: Beschwörungen und Feuerflächen), Bossraum mit Einsperren und Belohnungstruhe, Ablauf Dorf → Ebene 1 → Ebene 2 → Boss → Dorf, Tod und Wiederbelebung, Speichern und Laden (Figur, Stufe, Inventar, Gold, Einstellungen) mit Versionsnummer, Titelbildschirm, Musik, Balancing (Dauer, Schwierigkeitskurve), Simulationstest über den ganzen Ablauf.
- **Schnittstellen:** nutzt alles; sendet `boss_phase_changed`, `run_completed`.
- **Abhängigkeiten:** AP1 bis AP8.
- **Fertig, wenn:** Joshua spielt ohne Hilfe von Stufe 1 bis zum besiegten Boss, der Spielstand übersteht einen Neustart.

---

## 8. Wellen: was gleichzeitig laufen kann

```
Welle 1 │ AP0 Gerüst + Verträge                                           (1 Thread, Cloud)
────────┼──────────────────────────────────────────────────────────────────────────────
Welle 2 │ AP2 Spieler+Kampf │ AP4 Beute │ AP6 Dungeon │ AP8 Assets+Animation (PC)
────────┼──────────────────────────────────────────────────────────────────────────────
Welle 3 │ AP3 Gegner+KI │ AP5 Skills │ AP7 UI │ AP1 Grafik+Licht (PC)
────────┼──────────────────────────────────────────────────────────────────────────────
Welle 4 │ AP9 Boss, Ablauf, Speichern, Balancing → Anspielen durch Joshua → Version 0.1
```

Warum so geschnitten:
- In Welle 2 berühren sich die Pakete kaum: AP4 und AP6 sind reine Logik, AP2 nur Spieler und Schaden, AP8 nur Assets.
- Welle 3 braucht deren Ergebnisse: Gegner brauchen Kampf und Dungeons, Skills brauchen den Kampfkern, die UI braucht echte Gegenstände, der Grafikpass braucht echte Modelle.
- Pro Welle läuft höchstens ein Paket auf dem PC, damit sich zwei Sessions nicht denselben Ordner teilen.
- Ohne PC-Ordner laufen AP8 und AP1 ebenfalls in der Cloud; dann prüft Joshua jeden Stand im Build.

Regeln für die parallelen Threads:
1. Jeder Thread arbeitet nur in seinen Ordnern (Abschnitt 4) plus eigener Testszene, eigenen Daten und Tests.
2. Änderungen an `scripts/contracts/`, `autoload/` oder der Hauptszene sind ein eigener kleiner PR, der zuerst gemergt wird.
3. Kleine PRs, oft mergen; `main` ist immer spielbar.
4. Gemergt wird nur mit grüner CI.
5. Am Ende schreibt jeder Thread `docs/pakete/AP<n>.md`: was gebaut ist, wie man es testet, was offen ist.

---

## 9. Meilensteine bis Version 0.1

| Meilenstein | Inhalt | Pakete | Woran Joshua es erkennt |
|---|---|---|---|
| **M0 Gerüst** | Repo, Projekt, CI, Verträge, Windows-Build | AP0 | Build startet auf dem PC |
| **M1 Bewegen und Schlagen** | Spieler läuft durch einen erzeugten Dungeon und schlägt Puppen, erste echte Modelle | AP2, AP6, AP8 (+AP4 Logik) | Testszene „Dungeon“ spielbar |
| **M2 Erster Kampf** | Gegner greifen an, sterben, lassen Beute fallen | AP3 | 5 Minuten Kämpfen machen Spaß |
| **M3 Beute, Build und Look** | Inventar, Ausrüsten, Skills, Wut, Stufenaufstieg, Licht und Effekte | AP5, AP7, AP1 | Zwei Builds fühlen sich unterschiedlich an, das Bild wirkt düster und hochwertig |
| **M4 Version 0.1** | Boss, ganzer Ablauf, Speichern, Musik, Feinschliff | AP9 | Kompletter Durchlauf von Stufe 1 bis zum Boss |

Zu jedem Meilenstein gibt es einen Windows-Build zum Herunterladen und eine kurze Nachricht an Joshua mit der Bitte ums Anspielen.

---

## 10. Weg zu Version 1.0

| Version | Schwerpunkt |
|---|---|
| 0.2 | Tiefe: mehr Gegner und Elites, 12 Aspekte, Schmied (Neu-Würfeln von Affixen), Stufen bis 20 |
| 0.3 | Grafikpass: finale Stilrichtung, Entscheidung über gekaufte Assets, bessere Effekte und Klang |
| 0.4 | Klasse 2: **Jägerin** (Fernkampf mit Bogen und Dolchen, Ressource Energie) |
| 0.5 | Gebiet 2 „Moorwald“ mit eigenem Dungeon, Boss 2, Oberwelt-Dorf mit Wegpunkten |
| 0.6 | Klasse 3: **Totenrufer** (Magie und Diener, Ressource Essenz) |
| 0.7 | Gebiet 3 „Frostzitadelle“ mit Dungeon und Boss 3, erzählerischer Rahmen in Texten und Dialogen |
| 0.8 | Endgame: Schwierigkeitsstufen, „Albtraum-Dungeons“ mit Zusatzregeln, Paragon-Brett über Stufe 50 |
| 0.9 | Controller-Unterstützung, Optimierung, Balancing aller Klassen, Einstellungen, Tutorial |
| **1.0** | 3 Klassen, 3 Gebiete, mindestens 4 Bosse, rund 25 Gegnertypen, Endgame, stabiler Windows-Build |

Ab 0.2 schneiden wir die Arbeit pro Version wieder in Pakete nach demselben Muster: neue Inhalte sind meist neue Daten und Szenen, die parallel entstehen können (zum Beispiel ein Thread pro Klasse oder pro Gebiet).

---

## 11. Risiken und Gegenmaßnahmen

| Risiko | Gegenmaßnahme |
|---|---|
| Cloud-Threads sehen das Bild nicht | Grafik- und Animationspakete auf dem PC; Simulationstests für Logik; jeder Meilenstein als Build für Joshua |
| Konflikte in Szenendateien | Jede Szene gehört einem Paket, gemeinsame Szenen nur per kleinem PR |
| Parallele Threads bauen aneinander vorbei | Verträge zuerst (AP0), Ersatz-Dienste, feste Ordner |
| Spielgefühl stimmt nicht | M1 früh anspielen; Trefferstopp, Rückstoß und Wackeln als einstellbare Werte |
| Grafikanspruch vs. kostenlose Assets | Licht und Nachbearbeitung zuerst; Kaufentscheidung vor 0.3 |
| Leistung bei vielen Gegnern und Lichtern | Objekt-Pools, begrenzte Schatten-Lichter, Leistungstests in AP1 und AP3 |
| Git-LFS-Kontingent läuft voll | Nur importierbare Dateien committen, Blender-Quellen extern; Verbrauch beobachten |
| Umfang wächst | Inhalt von 0.1 ist fest (Abschnitt 3); alles andere wandert in Abschnitt 10 |
| Rechtliches | Eigene Namen und Figuren, nur Assets mit geprüfter Lizenz, `CREDITS.md` |

---

## 12. Vorlage für den Auftrag an einen Thread

> Du arbeitest an **AP<n> – <Name>** im Repo `bretalljoshua-sudo/Diablo-X` (Godot 4.7, GDScript streng typisiert). Lies zuerst `docs/PLAN.md` (Abschnitte 4, 6 und dein Paket in 7) und `CONTRIBUTING.md`. Arbeite auf dem Branch `ap<n>-<kurzname>`, nur in deinen Ordnern, deinen Daten in `data/`, deiner Testszene in `debug/` und deinen Tests. Godot läuft bei dir headless: prüfe mit GUT-Tests und Simulationstests. Brauchst du eine Änderung an `scripts/contracts/`, `autoload/` oder der Hauptszene, mach dafür einen eigenen kleinen PR mit Präfix `contracts:`. Liefere über PRs gegen `main` mit grüner CI. Fertig bist du, wenn die „Fertig, wenn“-Bedingung deines Pakets erfüllt ist; schreibe dann `docs/pakete/AP<n>.md`.
