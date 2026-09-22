# AP8 – Assets und Animation

Stand: 22.09.2026 · Godot 4.7.2

## Was gebaut ist

| Bereich | Wo |
|---|---|
| Krieger und vier Gegner als fertige Szenen mit Modell, Waffe, AnimationTree und Klängen | `assets/characters/warrior.tscn`, `skeleton_swarm.tscn`, `ghoul.tscn`, `skeleton_archer.tscn`, `cultist_summoner.tscn` |
| Gemeinsames Skelett: alle Figuren auf Godots Humanoid-Profil umgemappt (`%GeneralSkeleton`), eine Animationsquelle für alle | `assets/animations/kaykit_bone_map.tres`, `assets/animations/kaykit_humanoid_anims.glb` |
| 42 aufbereitete Clips, je Figur eine Bibliothek mit festen Namen, ein gemeinsamer Zustandsautomat | `assets/animations/clips/`, `assets/animations/libraries/`, `assets/animations/character_state_machine.tres` |
| Treffer-, Auslöse- und Schrittzeitpunkte als Methodenspuren in den Clips | berechnet in `assets/tools/build_animations.gd` |
| Schnittstelle der Figuren (Klasse `CharacterModel`) | `assets/characters/character_model.gd` |
| Baukasten für Katakomben und Dorf als MeshLibrary, 40 Teile mit Namen, IDs und Drehung laut AP6 | `assets/world/world_kit.tres`, Meshes in `assets/world/meshes/` |
| Requisiten als eigene Szenen (StaticBody3D mit Mesh und Kollision) | `assets/props/*.tscn` |
| Klänge mit Varianten: Schritte, Schwung, Treffer, Schmerz, Tod, Knochenbruch, Zauber, Beute fällt (normal, selten, legendär), Aufheben, Gold | `assets/audio/*.tres`, Klasse `GameSounds` in `assets/audio/game_sounds.gd` |
| Quellen und Lizenzen | `assets/CREDITS.md` |
| Testszene | `debug/asset_gallery.tscn` |
| Tests: Skelett, Animationen, Spurpfade, Zeitpunkte, Waffen, Blickrichtung, Tempo, AP2-Schnittstelle, Treffer im laufenden Baum, Baukasten, Klänge, Galerie | `tests/unit/test_ap8_*.gd`, `tests/sim/test_ap8_*.gd` |

### Figuren

| Szene | Modell (KayKit) | Waffe | Angriff 1 | Besonderheit |
|---|---|---|---|---|
| `warrior` | Barbar | Zweihandaxt | Hieb, Treffer bei 0,45 s | Angriff 3 ist der Wirbelsturm (Schleife) |
| `skeleton_swarm` | Skelett-Diener, 95 % | Klinge | Hacken | schnell, zerfällt beim Tod |
| `ghoul` | Skelett-Krieger, 135 %, grünlich | Axt | schwerer Zweihandhieb | langsam |
| `skeleton_archer` | Skelett-Schurke | Armbrust | Schuss, Auslösen bei 0,3 s | Angriff 3 Zielen (Schleife), 4 Nachladen |
| `cultist_summoner` | vermummte Schurkin, karmesin | Stab | Zauberschuss | `cast` ist die Beschwörung (Auslösen bei 3,1 s) |

Jede Figur hat dieselben Animationsnamen: `idle`, `walk`, `run` (Fortbewegung) und die Aktionen
`attack_1` bis `attack_4`, `cast`, `hit`, `dodge`, `spawn`, `block`, `interact`, `death`.
Die Modelle schauen nach −Z (Godot-Konvention).

## Wie man es testet

- **Testszene:** `godot --path . -- --scene=asset_gallery`, im Windows-Build
  `SpielJBR.exe --scene=asset_gallery`. Alle fünf Figuren stehen in einem Raum aus dem Baukasten und
  zeigen nacheinander jede Animation.
  Tasten: Leertaste nächste Animation · A Automatik an/aus · 1 bis 5 eine Figur heranholen ·
  Tab Übersicht aller 40 Baukasten-Teile · L und K Klang für seltene und legendäre Beute · Mausrad Zoom.
- **Im Spiel:** Der Krieger ist die Spielerfigur (AP2 lädt `warrior.tscn`), die Welt von AP6 baut
  Katakomben und Dorf aus dem Baukasten (`godot --path . -- --scene=world_test`).
- **Tests:** `tools/run_tests.sh` (alle), die AP8-Tests heißen `test_ap8_*`.
- **Neu bauen** (nur nötig, wenn Quellen oder Zuordnungen geändert werden, erst importieren mit
  `godot --headless --path . --import`):
  - Animationen: `godot --headless --path . -s res://assets/tools/build_animations.gd`
  - Baukasten und Requisiten: `godot --headless --path . -s res://assets/tools/build_world_kit.gd`
  - Klänge: `python3 assets/tools/synth_sounds.py`, dann
    `godot --headless --path . -s res://assets/tools/build_sounds.gd`

## Für andere Pakete

### Figuren (AP2, AP3, AP9)

Szene laden, instanziieren, als Kind der Spielfigur einsetzen. Die Figur ist ein `Node3D` ohne
Physik; Bewegung und Kollision macht der Besitzer.

| Aufruf | Wirkung |
|---|---|
| `set_move_velocity(m_pro_s)` | Fortbewegung nach tatsächlicher Geschwindigkeit: stehen, gehen, laufen, bei mehr Tempo schneller abgespielt (höchstens 1,8-fach) |
| `set_move_speed(anteil)` | dasselbe als Anteil 0 bis 1 von `reference_max_speed` (6 m/s), für `player.gd` |
| `play_action(name, tempo = 1.0) -> bool` | spielt eine Aktion. `attack` = `attack_1` mit `tempo` als Angriffe pro Sekunde, `stunned` = `hit`, `idle`/`walk`/`run` beenden die Aktion. `false` bei unbekanntem Namen oder wenn tot |
| `stop_action()` | beendet eine laufende Aktion (nötig für Schleifen: `attack_3` des Kriegers und des Bogenschützen) |
| `play_hit()`, `play_dodge()`, `play_death()`, `revive()` | Trefferreaktion mit Schmerzlaut, Rolle, Tod mit Klang (bleibt liegen), Wiederbeleben |
| `is_busy()`, `is_dead()`, `get_current_action()` | Zustand |
| `get_action_length(name)`, `get_event_time(name, event)` | Länge eines Clips und Zeitpunkt von `hit`, `release` oder `footstep` in Sekunden (−1 = keiner) |

Signale: `hit_frame` (Nahkampf trifft, jetzt Schaden austeilen), `release_frame` (Pfeil oder Zauber
löst sich, jetzt Geschoss erzeugen), `footstep`, `action_finished(name)`, `anim_event(name)`.
Jeder Clip feuert sein Ereignis genau einmal je Durchlauf; bei höherem Tempo kommt es entsprechend früher.

Für `EnemyDef.scene` (AP3) stehen die Pfade fest: `res://assets/characters/<gegner>.tscn` mit
`skeleton_swarm`, `ghoul`, `skeleton_archer`, `cultist_summoner`. Die Figur kommt dann als Modell unter
den Gegner-Körper, wie beim Spieler.

### Baukasten (AP6)

`res://assets/world/world_kit.tres`, Namen und IDs identisch mit `WorldTiles`; Absprache und Regeln
stehen in `docs/pakete/AP6.md`. `WorldKit.uses_real_kit()` ist damit `true`. Wände stehen an der
+Z-Seite der Zelle, die Türöffnung steht wie der Platzhalter mittig in der Zelle.

### Klänge (AP2, AP3, AP4, AP7)

`GameSounds.play_at(GameSounds.LOOT_DROP_RARE, position, self)` spielt einen Klang einmal im Raum.
Weitere: `FOOTSTEP`, `SWING`, `IMPACT` (Waffe trifft Körper, gedacht für den Kampfdienst), `HURT`,
`DEATH`, `BONE_BREAK`, `CAST`, `LOOT_DROP`, `LOOT_DROP_LEGENDARY`, `LOOT_PICKUP`, `GOLD_PICKUP`.
Die Figuren spielen Schritte, Schwung, Schmerz und Tod selbst. Klänge laufen über den Bus `Effects`,
falls es ihn gibt, sonst über `Master`.

## Verträge

Keine geändert.

## Abweichungen vom Plan und Festlegungen

- **Nur KayKit, Kenney und eigene Klänge.** Quaternius, Poly Haven, ambientCG und kenney.nl waren
  aus der Cloud nicht erreichbar (Proxy 403). Die KayKit-Pakete (CC0) kamen über GitHub.
- **Stil:** KayKit ist bunt und niedlich (große Köpfe), kein düsterer Realismus wie Diablo 4. Für 0.1
  reicht es; die Kaufentscheidung vor 0.3 (siehe Plan) sollte den Stil ersetzen. Weil alle Clips auf
  dem Humanoid-Profil liegen, lassen sich andere humanoide Modelle mit eigener BoneMap einsetzen.
- **Keine PBR-Texturen:** KayKit nutzt einen Farbatlas je Paket. Gras und Spinnennetz sind eigene,
  prozedural erzeugte Texturen.
- **Kein Git LFS für `assets/`:** Aus der Cloud lässt sich nicht zu LFS hochladen, deshalb liegen die
  Assets als normale Dateien im Repo (`assets/.gitattributes`, insgesamt rund 12 MB). Das LFS-Kontingent
  ließ sich aus der Cloud nicht prüfen. Klonen mit und ohne git-lfs steht in `CONTRIBUTING.md`.
- **Treffer-Zeitpunkt:** aus der Handbewegung berechnet (schnellster Moment der Waffenhand, dann das
  Abbremsen), Auslöse-Zeitpunkte für Schuss und Zauber von Hand gesetzt.
- **Gehen und Laufen sind langsam** (etwa 0,6 und 2,45 m/s beim Krieger), die Figuren sind klein. Bei
  schnellerer Bewegung wird die Animation schneller abgespielt, damit die Füße weniger rutschen.

## Offen

- **Am PC ansehen:** Alles ist nur mit Software-Rendering in der Cloud geprüft. Licht, Größe der
  Fackeln, Sarg und Gruft-Eingang, Farben von Ghul und Kultist bitte im Windows-Build ansehen.
- **Türöffnung** steht mittig in der Zelle, die Wände an der Kante; die Öffnung wirkt dadurch etwas
  zurückgesetzt. Falls es stört, rückt sie in `build_world_kit.gd` an die Kante (Absprache mit AP6).
- **Eigene Todesanimationen** für Kultist und Ghul fehlen (sie nutzen die Standard-Tode), ebenso eine
  eigene Rolle für Gegner (Seitwärts- und Rückwärtssprung).
- **Boss (AP9):** kein eigenes Modell. Vorschlag: Skelett-Krieger oder Barbar vergrößert und umgefärbt
  über `tint` und `albedo_override`, oder ein gekauftes Modell mit BoneMap.
- **Weitere Klassen (1.0):** Die Adventurers enthalten Magier, Schurke und Ritter mit demselben Skelett.
