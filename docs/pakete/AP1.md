# AP1 – Grafik, Licht und Kamera

Stand: 23.09.2026. Gebaut in der Cloud mit Software-Rendering (Forward+ über Lavapipe), also ohne
echte Grafikkarte. Aussehen und Leistung muss Joshua auf seinem PC prüfen (siehe unten).

## Was gebaut ist

- **Kamera-Rig** (`graphics/camera_rig.gd`, `CameraRig`): fester isometrischer Winkel (45° Drehung,
  52° Neigung, Sichtfeld 40°), weiches Folgen mit leichter Vorausschau in Laufrichtung, Zoom mit
  dem Mausrad (Standard 19 m, 10 bis 26 m, weich), Kamerawackeln mit Rauschen, Abklingen und leichter Rollbewegung
  (`shake(stärke, dauer)`, gedeckelt, `shake_scale` für eine spätere Einstellung „Wackeln“).
  Sprünge über 5 m (Teleport, Ebenenwechsel) setzen die Kamera sofort um. Trefferstopp
  (`Engine.time_scale`) bremst die Kamera nicht. `screen_to_ground()` und `get_active()` wie in AP0.
- **Umgebungen** (`graphics/environments/village.tres`, `catacombs.tres`, `boss.tres`): AgX-Tonemapping,
  SSAO, SSIL, SDFGI, SSR, Glühen, Tiefen- und Höhennebel, Volumennebel und Farbkorrektur. Die
  Ebene aus AP6 lädt sie automatisch nach Thema. Der düstere Look kommt vor allem aus Licht, Nebel
  und Farbkorrektur, denn die KayKit-Modelle sind bunt.
- **Licht** (`graphics/lights/`): Vorlagen für Fackel, Feuerschale, Laterne, Krypta-Eingang,
  Spielerlicht und Beute (`LightPresets`), flackernde Flammen (`LightFlicker`) mit Glut-Partikeln.
  Regel: Schatten bekommen nur die nächsten N Lichter um den Spieler (N je Grafikstufe, 2 bis 10),
  alle 0,4 s neu verteilt. Das Spielerlicht wirft keinen Schatten. Ferne Lichter blenden aus.
- **Materialien** (`graphics/materials/material_library.gd`): Stein, Fels, Putz, Dach, Holz,
  Metall, Knochen, Stoff, Gras, Erde, Pflaster, Laub, mit Rausch-Texturen in Weltkoordinaten und
  nassen Stellen am Boden. Wände, die den Spieler verdecken, werden weich ausgeblendet
  (Shader-Globals `occlusion_target` und `occlusion_radius`).
- **Effekte** (`graphics/vfx/`, Autoload `Vfx`): Treffer, Blut, Knochensplitter, Funken, Feuer,
  Kälte, Gift, kritischer Treffer, Todesstoß, Staub, Aufschlag, Stufenaufstieg und je ein Effekt
  für die sieben Krieger-Skills, dazu Feuerring und Ahnen-Einschlag. Aus Pools, mit kurzem
  Lichtblitz und Ring. Dazu Schadenszahlen (weiß, kritisch gold mit „!“, Schaden am Spieler rot,
  Feuer, Kälte, Gift eingefärbt), Treffer-Aufblitzen am Modell, Blutflecken am Boden (Budget je
  Stufe), Auflösen beim Tod (glühende Kante) und Beute-Lichtsäulen nach Seltenheit (Magisch glimmt,
  Selten kurze Säule, Legendär und Einzigartig hohe Säule).
- **Grafikstufen** (`graphics/quality/*.tres`, Autoload `Graphics`): Niedrig, Mittel, Hoch, Ultra.
  Umschalten im Einstellungsmenü von AP7 oder mit F5 bis F8 in den Testszenen. Die Stufen schalten
  Kantenglättung, Auflösungsskalierung (FSR), SDFGI, SSAO, SSIL, SSR, Volumennebel, Schatten-Größe,
  Anzahl Schatten-Lichter, Partikelmenge und Blutflecken.

| Stufe | Kantenglättung | Skalierung | GI / Nebel | Schatten-Lichter |
|---|---|---|---|---|
| Niedrig | FXAA | FSR 67 % | aus / aus | 2 |
| Mittel | MSAA 2× | FSR 2 77 % | aus / grob | 4 |
| Hoch | MSAA 2× | 100 % | SDFGI halb, SSR / mittel | 6 |
| Ultra | MSAA 4× | 100 % | SDFGI voll, SSIL, SSR / fein | 10 |

## Wie man es testet

Im Windows-Build (Artifact des Laufs „Windows-Export“ in GitHub Actions):

- `SpielJBR.exe --scene=graphics_test` – echte Ebene mit Licht und Nebel und sechs Gegnern aus AP8.
  `--depth=0` Dorf, `1`/`2` Katakomben, `3` Bossraum, `--showcase` löst nach einer Sekunde Treffer,
  Tod, Beute und einen Kriegsschrei aus.
  Tasten: F5 bis F8 Grafikstufe · 0 bis 3 Ebene · H Treffer · C kritischer Treffer · K Gegner töten ·
  L Beute fallen lassen · E Effekt am Mauszeiger, V wechselt ihn · J Wackeln · O Wände ausblenden
  an/aus · Mausrad Zoom · WASD oder Linksklick laufen.
- `SpielJBR.exe --scene=graphics_perf` – Leistungstest: Bossraum, 50 animierte Gegner, laufend
  Treffer, Schadenszahlen, Blut, Auflösen und Lichtsäulen. Große FPS-Anzeige oben links (grün ab 60).
  Tasten: F5 bis F8 Grafikstufe · B Messung dieser Stufe (3 s Aufwärmen, 12 s messen) · F11 Vollbild ·
  P Effekte an/aus. Weitere Schalter: `--enemies=80`, `--quality=2`.
- `SpielJBR.exe --scene=graphics_perf --benchmark` misst alle vier Stufen nacheinander, schreibt
  das Ergebnis nach `%APPDATA%\Godot\app_userdata\Spiel JBR\benchmark.txt` (der genaue Pfad steht
  im Log) und beendet sich.
- Im Spiel wirkt alles automatisch: `SpielJBR.exe --scene=world_test`, `combat_test`, `skills_test`.
- Tests: `tools/run_tests.sh`; AP1-Tests sind `test_camera_rig`, `test_graphics_quality`, `test_vfx`
  und `tests/sim/test_graphics_scenes.gd`.
- Bilder ohne Grafikkarte: `graphics/tools/render_shots.sh <ordner> <name> <szene> [argumente]`
  (Forward+ über Lavapipe, sonst Compatibility).

## Bilder

Im Projektordner unter `screenshots/ap1/` (gerendert in der Cloud mit Software-Rendering, auf
„Hoch“, gleicher Seed vorher und nachher, „vorher“ ist main vor AP1 mit dem AP8-Baukasten):
`vergleich_katakomben.png`, `vergleich_dorf.png`, `vergleich_bossraum.png` (nebeneinander),
`vorher_*.png` und `nachher_*.png` in voller Größe, `effekte_katakomben.png` und
`effekte_bossraum.png` (Treffer, kritische Zahlen, Beute-Lichtsäule, Kriegsschrei),
`leistungstest_50_gegner.png` (die FPS-Zahl darin ist die der Cloud, nicht aussagekräftig).

## Was Joshua auf dem PC prüfen sollte

1. **Leistung:** `graphics_perf` in 2560 × 1440 im Vollbild (F11) auf „Hoch“ (F7), B drücken.
   Ziel: 60 FPS im Schnitt, 1-%-Tiefs nicht unter 50. Oder gleich `--benchmark` und die Datei schicken.
2. **Helligkeit:** Sind die Katakomben zu dunkel oder zu hell? Stellschrauben:
   `ambient_light_energy` und die Farbkorrektur in `graphics/environments/catacombs.tres`,
   Spielerlicht in `graphics/lights/light_presets.gd` (`PLAYER`).
3. **Nebel:** Volumennebel sieht auf echter Grafikkarte weicher aus als in der Cloud. Wenn er
   flimmert oder zu dicht ist: `volumetric_fog_density` in den Umgebungen.
4. **Ausblenden der Wände:** Wände vor der Figur sollen gerastert durchsichtig werden (O schaltet
   es in `graphics_test` aus zum Vergleich).
5. **Kamera:** Winkel, Zoombereich und Wackeln. Wenn das Wackeln stört, `shake_scale` am Rig.

## Schnittstellen für andere Pakete

- `CameraRig.get_active()`, `shake(strength, duration)`, `screen_to_ground(screen_position)`,
  `snap_to_target()`, `yaw_degrees`, `camera`.
- `Vfx.spawn(key, position) -> Node3D` (null, wenn es den Schlüssel nicht gibt). Schlüssel stehen in
  `VfxLibrary.SPECS`. Treffer-Schlüssel aus AP5 (`<vfx_key>_hit`) werden aufgelöst
  (`Vfx.resolve_key`). Skill-Effekte über `spawn()` wackeln nicht an der Kamera, das macht AP5.
- `Vfx` hört selbst auf `damage_dealt`, `entity_died`, `entity_spawned`, `loot_dropped`,
  `loot_picked_up`, `skill_cast`, `level_unloading`. Bei `skill_cast` startet es den Effekt aus
  `SkillDef.vfx_key`, außer bei Sprung und Kriegsschrei, deren Effekt im Treffermoment kommt.
- Figuren wählen ihren Treffer-Effekt über das Meta `hit_vfx` (zum Beispiel `&"bone_chips"`,
  `&"sparks"`) und die Trefferhöhe über `hit_height`. Skelette erkennt `Vfx` am Modell.
- `Graphics.apply_quality(level)`, `Graphics.get_preset()`, Signal `quality_applied`.
  `Graphics.decorate_level()` richtet Lichter und Materialien einer Ebene ein, das passiert
  automatisch bei `level_loaded`.

## Vertragsänderungen

- `contracts:` Autoloads `Graphics` und `Vfx` nach `World`, Shader-Globals `occlusion_target` und
  `occlusion_radius` in `project.godot`, Einträge in der Dienst-Tabelle von `CONTRIBUTING.md`.

## Offen

- Leistung und Aussehen auf echter Grafikkarte sind nicht gemessen (Cloud rendert in Software).
  Die Zahlen aus dem Benchmark entscheiden, ob „Hoch“ nachgeschärft werden muss.
- Grafikstufen „Niedrig“ und „Mittel“ sind nur rechnerisch abgestuft, nicht auf schwacher
  Hardware geprüft.
- Kaufentscheidung Assets vor 0.3: mit dunkleren Texturen ließe sich die Farbkorrektur zurücknehmen.
- Boss-Effekte (Angriffe, Phasen) kommen mit AP9 dazu, als neue Schlüssel in `VfxLibrary.SPECS`.
