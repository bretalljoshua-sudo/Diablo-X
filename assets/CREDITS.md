# Quellen und Lizenzen

Jede eingebundene Quelle (Modelle, Texturen, Klänge, Musik, Schriften) steht hier mit Lizenz und Link.
Pflege: AP8. Alle Spiel-Assets sind CC0 (gemeinfrei); Namensnennung ist nicht nötig, wir nennen die
Urheber trotzdem.

| Was | Quelle | Lizenz | Ordner |
|---|---|---|---|
| GUT (Testwerkzeug) | https://github.com/bitwes/Gut | MIT | `addons/gut/` |
| KayKit Character Pack: Adventurers 1.0 (Kay Lousberg) – Barbar (Krieger), vermummte Schurkin (Kultist), Waffen | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 · https://kaylousberg.itch.io/kaykit-adventurers | CC0 1.0 | `assets/characters/kaykit/`, `assets/weapons/` |
| KayKit Character Pack: Skeletons 1.0 (Kay Lousberg) – Skelette, Animationen, Skelett-Waffen | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0 · https://kaylousberg.itch.io/kaykit-skeletons | CC0 1.0 | `assets/characters/kaykit/`, `assets/animations/`, `assets/weapons/skeleton_*` |
| KayKit Dungeon Remastered 1.0 (Kay Lousberg) – Böden, Wände, Säulen, Treppen, Fässer, Truhen, Fackeln | https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0 · https://kaylousberg.itch.io/kaykit-dungeon-remastered | CC0 1.0 | `assets/world/kaykit_dungeon/` |
| KayKit Halloween Bits 1.0 (Kay Lousberg) – Särge, Kerzen, Gruft, Bäume, Zaun, Laterne | https://github.com/KayKit-Game-Assets/KayKit-Halloween-Bits-1.0 · https://kaylousberg.itch.io/halloween-bits | CC0 1.0 | `assets/world/kaykit_halloween/` |
| KayKit Medieval Hexagon Pack 1.0 (Kay Lousberg) – Brunnen, Felsen | https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0 · https://kaylousberg.itch.io/kaykit-medieval-hexagon | CC0 1.0 | `assets/world/kaykit_medieval/` |
| Kenney Starter Kits (FPS, 3D Platformer, City Builder) – Klänge: Schmerz, Zerfall, Zauber, Münze, Aufprall, Ablegen | https://github.com/KenneyNL/Starter-Kit-FPS · https://github.com/KenneyNL/Starter-Kit-3D-Platformer · https://github.com/KenneyNL/Starter-Kit-City-Builder · https://kenney.nl | Klänge CC0 1.0 (Code der Kits MIT, nicht übernommen) | `assets/audio/kenney/` |

## Eigene Ableitungen (ebenfalls CC0)

| Was | Abgeleitet aus | Ordner |
|---|---|---|
| Verkleinerte Figuren ohne Animationen, eine gemeinsame Animationsquelle | KayKit-Figuren (Animationen und nicht genutzte Teile entfernt) | `assets/characters/kaykit/`, `assets/animations/kaykit_humanoid_anims.glb` |
| Aufbereitete Clips mit Trefferzeitpunkten, Bibliotheken je Figur, Zustandsautomat | erzeugt mit `assets/tools/build_animations.gd` | `assets/animations/` |
| Kultist-Farbtextur (dunkles Karmesin statt Grün) | `rogue_texture.png` aus den Adventurers | `assets/characters/textures/` |
| Baukasten `world_kit.tres`, zusammengesetzte Meshes, Requisiten-Szenen | KayKit-Teile, erzeugt mit `assets/tools/build_world_kit.gd` | `assets/world/`, `assets/props/` |
| Gras- und Spinnennetz-Textur | eigene, prozedural erzeugt | `assets/world/textures/grass_ground.png`, `cobweb.png` |
| Schritte, Schwünge, Treffer, Beuteklänge (selten, legendär) | eigene, erzeugt mit `assets/tools/synth_sounds.py` | `assets/audio/synth/` |
| Klang-Ressourcen mit Varianten (`*.tres`) | erzeugt mit `assets/tools/build_sounds.gd` | `assets/audio/` |
| Musik: Dorf, Katakomben, Bosskampf (AP9) | eigene, erzeugt mit `encounters/tools/compose_music.gd` (keine Samples) | `assets/audio/music/` |
