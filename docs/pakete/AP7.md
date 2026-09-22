# AP7 – UI und Inventar

Stand: 22.09.2026 · alles in `ui/`, Testszene `debug/ui_test.tscn`

## Was gebaut ist

| Bereich | Wo |
|---|---|
| Gesamte Oberfläche als eine Szene (CanvasLayer, Ebene 10) | `ui/game_ui.tscn`, `ui/game_ui.gd` (`GameUI`) |
| Theme im düsteren ARPG-Stil (dunkler Stein, Bronze, Gold), im Code erzeugt | `ui/theme/ui_theme.gd` (`UiTheme`) |
| Fenstergrundlage mit Titel und Schließen-Kreuz | `ui/common/ui_window.gd` (`UiWindow`) |
| Gegenstandssymbole (bis AP8 Symbole liefert: Zeichen je Platz, Farbe nach Seltenheit) | `ui/common/item_icon.gd` |
| Tooltip mit farbigem Vergleich (grün ▲ besser, rot ▼ schlechter), daneben der angelegte Gegenstand | `ui/common/item_tooltip.gd` |
| HUD: Lebens- und Wut-Kugel (Flüssigkeits-Shader mit Nachlauf), Heiltrank, Skillleiste mit Abklingzeiten, Erfahrungsbalken mit Stufe, Menüknöpfe | `ui/hud/` |
| Lebensbalken über Gegnern (bei Schaden oder unter der Maus, mit Namen, Elite goldumrandet) | `ui/hud/enemy_health_bars.gd` |
| Bossbalken mit Phasenmarke bei 50 % | `ui/hud/boss_bar.gd` |
| Minikarte oben rechts, große Karte mit M, Nebel des Unbekannten, gedreht wie die Kamera | `ui/hud/minimap.gd` |
| Beschriftungen am Boden mit Alt, Klick auf ein Schild hebt auf, Tooltip beim Überfahren | `ui/hud/ground_labels.gd` |
| Inventar-Fenster: Ausrüstung um die Figurvorschau, Werte, Raster, Gold | `ui/inventory/` |
| Figurvorschau: echtes Modell `assets/characters/warrior.tscn` (AP8), dreht sich, mit der Maus drehbar | `ui/inventory/character_preview.gd` |
| Skillbaum nach Kategorien, Ränge, Sperrgründe, Details, auf die Leiste legen | `ui/skills/` |
| Händler: kaufen per Klick, verkaufen per Rechtsklick im Inventar | `ui/merchant/` |
| Pausenmenü (hält das Spiel an) mit Einstellungen: Grafik, Ton, Tastenbelegung | `ui/menu/` |
| Testszene mit Beispieldaten für alles, was noch fehlt | `debug/ui_test*.gd`, `debug/ui_test.tscn` |
| 24 Tests (4 Unit-, 20 Simulationstests mit echten Maus- und Tastaturereignissen) | `tests/unit/test_ui_components.gd`, `tests/sim/test_ui_*.gd`, Grundlage `tests/sim/ui_sim_test.gd` |

### Bedienung

| Taste / Maus | Wirkung |
|---|---|
| I | Inventar und Charakter |
| K | Skillbaum (S ist Laufen, siehe AP0) |
| M oder Tab | große Karte |
| Esc | offene Fenster schließen, sonst Pausenmenü; in den Einstellungen zurück |
| Alt (halten) | Beute am Boden beschriften |
| Inventar: Rechtsklick / Enter | anlegen (beim Händler: verkaufen) |
| Inventar: Linksklick / Leertaste | aufnehmen und woanders ablegen, auch auf einen Ausrüstungsplatz |
| Inventar: Pfeiltasten | Auswahl bewegen; am Rand geht der Fokus zu den Ausrüstungsplätzen |
| Ausrüstungsplatz: Rechtsklick / Enter | ablegen |
| Skillbaum: Klick / Enter | Rang erhöhen |
| Skillbaum: 1–4 / Rechtsklick / Knöpfe unten | Skill auf die Leiste legen |
| Menüknöpfe neben der Skillleiste, Klick auf einen Skillplatz | Fenster mit der Maus öffnen |

Tastenbelegungen lassen sich im Pausenmenü unter „Steuerung“ ändern (gespeichert mit „Speichern“ in
`user://settings.cfg`). Skillleiste und Heiltrank zeigen die aktuelle Belegung.

## Wie man es testet

```bash
tools/lint.sh
tools/run_tests.sh
godot --path . -- --scene=ui_test
```

Windows-Build: `SpielJBR.exe --scene=ui_test`. In der Testszene:

- **Ausrüstung:** I öffnet das Inventar mit 14 echten Gegenständen und einigen schwachen angelegten
  Stücken. Überfahren zeigt den Vergleich, Rechtsklick legt an, Linksklick nimmt auf.
- **Skills:** K öffnet den Skillbaum mit 2 freien Punkten. „Hieb“ lernen schaltet „Kern“ frei.
  Gelernte Skills landen auf der Leiste; 1–4 setzt sie ein (Wut, Abklingzeit, Aufleuchten).
  0 gibt eine Stufe und einen Punkt, 6 gibt Erfahrung.
- **HUD:** 5 nimmt Schaden, Q trinkt einen Trank (lädt nach), Gegner verlieren laufend Leben,
  Maus über einem Gegner zeigt den Namen.
- **Boss:** 8 startet und beendet einen Bosskampf mit Balken und Phasenwechsel.
- **Händler:** 9 öffnet „Händlerin Mira“ mit 10 Angeboten.
- **Beute:** Alt halten, Schild anklicken; 7 lässt mehr Beute fallen.
- **Karte:** WASD laufen, die Minikarte deckt auf; M zeigt die große Karte.
- **Bildschirmfotos:** `--ui-open=inventory,skills,merchant,map,pause,settings,labels,boss,tooltip`
  öffnet Fenster beim Start, zusammen mit `--screenshot=datei.png` aus AP0.

Die Simulationstests blenden die Oberfläche von GUT aus (sie liegt sonst über allem und fängt Klicks
ab) und klicken über `Viewport.push_input()`. In der Cloud lassen sich mit `xvfb-run` und
`--rendering-method gl_compatibility` auch Bildschirmfotos machen (langsam, aber gut für Layoutprüfung).

## Was die anderen Pakete liefern müssen

Die UI liest nur über den EventBus und die Verträge. Wer den Zustand besitzt, sendet ihn **beim
Start und bei jeder Änderung**. Wird die UI erst nach dem Spieler erzeugt, verpasst sie die
Startwerte: also `GameUI` zuerst einhängen oder die Startwerte mit `call_deferred` senden.

### AP2 (Spieler und Kampf) – liefert schon

| Signal | Wofür |
|---|---|
| `player_health_changed(current, maximum)` | Lebenskugel |
| `potion_charges_changed(charges, maximum, progress)` | Heiltrank |
| `entity_health_changed(entity, current, maximum)` | Balken über Gegnern und Bossbalken |
| `hovered_target_changed(target)` | Name und Balken des Gegners unter der Maus |
| `entity_died(entity, killer)` | Balken entfernen |

Am Gegner werden optional gelesen: `display_name: String` und `is_elite: bool` (sonst Knotenname).
`Inventory` und `Equipment` als Kinder von `Game.player` (AP2 macht das schon); `Stats.get_stat()`
für die Werte im Inventar.

### AP5 (Skills und Krieger)

| Signal | Richtung | Inhalt |
|---|---|---|
| `skill_tree_changed(state: SkillTreeState)` | AP5 → UI | alle Skills, Ränge, höchste Ränge, freigeschaltete Skills, freie Punkte, Sperrgründe; nach jeder Änderung neu |
| `skill_slot_changed(slot, skill)` | AP5 → UI | Platz 0 = Linksklick, 1 = Rechtsklick, 2–5 = Tasten 1–4; `null` = leer |
| `skill_cooldown_started(skill, duration)` | AP5 → UI | Abklingzeit nach Verringerung |
| `skill_cast(caster, skill, target)` | AP5 → UI | Platz leuchtet kurz |
| `skill_cast_failed(skill, reason)` | AP5 → UI | Platz blinkt rot |
| `resource_changed(current, maximum)` | AP5 → UI | Wut-Kugel, Plätze rot bei zu wenig Wut (`SkillDef.cost`) |
| `experience_changed(current, required, level)` | AP5 → UI | Erfahrungsbalken innerhalb der Stufe |
| `player_level_up(level)` | AP5 → UI | Stufenanzeige |
| `skill_rank_up_requested(skill)` | UI → AP5 | Wunsch „Rang +1“; die UI fragt nur, wenn `state.can_rank_up(skill)` |
| `skill_slot_assign_requested(slot, skill)` | UI → AP5 | Wunsch „auf die Leiste“, nur für gelernte Skills |

Vorbild für die Umsetzung ist `debug/ui_test_skills.gd` (Freischalten nach verteilten Punkten,
neue Skills auf den ersten freien Platz). `SkillDef.icon` ersetzt die Buchstaben-Symbole.

### AP6 (Dungeon und Dorf) – liefert schon

`level_loaded(layout)`. Die Minikarte baut ihr Bild mit `MinimapData.build_image(layout)` und rechnet
mit `MinimapData.world_to_pixel()`; dazu `layout.exits`, `layout.entrance` und `layout.markers`
(`merchant`, `stash`, `portal`, `boss_spawn`, `boss_chest` bekommen eigene Farben).

### AP9 (Boss, Ablauf, Speichern)

- `GameUI` in jede Spielszene hängen: `add_child(preload("res://ui/game_ui.tscn").instantiate())`.
- `boss_encounter_started(boss, "Der Gruftwächter")` und `boss_encounter_ended(boss)`; Leben über
  `entity_health_changed`, Phase über `boss_phase_changed`.
- Händler im Dorf (am Marker `merchant`): `merchant_opened(name, stock)`; die UI entfernt gekaufte
  Gegenstände aus `stock` und sendet `merchant_item_bought(item, price)` bzw.
  `merchant_item_sold(item, price)`. Das Sortiment würfelt AP9 (zum Beispiel `Loot.roll_drop()` mit
  der Tabelle `chest`).
- `ui_window_toggled(window, open)`: `&"inventory"`, `&"skills"`, `&"map"`, `&"merchant"`,
  `&"pause"`. `GameUI.is_any_window_open()` sagt, ob Fenster offen sind. Klicks auf Fenster fängt
  die UI selbst ab (sie erreichen `_unhandled_input` der Spielfigur nicht).
- Das Pausenmenü setzt `get_tree().paused`. Alles, was in der Pause laufen muss, braucht
  `PROCESS_MODE_ALWAYS`.

### AP1 und AP8

- AP1: Schadenszahlen (Plan: AP1) hängen an `damage_dealt`. Die Grafikstufe setzt die UI in
  `Settings.quality` und ruft `Settings.apply()`, die Wirkung baut AP1.
- AP4/AP1: `GroundItem` zeigt sein `Label3D` immer. Die Alt-Schilder liegen genau darüber und
  verdecken es; schöner wäre, das `Label3D` ganz zu entfernen, sobald AP1 die Beute gestaltet.
- AP8: Symbole für `ItemBase.icon` und `SkillDef.icon` (quadratisch, etwa 128 px), eine Schrift
  mit Umlauten für das Theme. Die Figurvorschau zeigt das echte Modell, aber noch nicht die
  angelegten Gegenstände daran.

## Verträge geändert

- `EventBus`: `entity_health_changed`, `experience_changed`, `skill_tree_changed`,
  `skill_slot_changed`, `skill_cooldown_started`, `skill_rank_up_requested`,
  `skill_slot_assign_requested`, `boss_encounter_started`, `boss_encounter_ended`,
  `merchant_opened`, `merchant_item_bought`, `merchant_item_sold`, `ui_window_toggled`.
- Neue Klasse `SkillTreeState` in `scripts/contracts/`.
- `Settings`: `music_volume`, `effects_volume` (Busse „Music“ und „Effects“, falls vorhanden),
  `key_bindings` mit `set_key_binding()`, `reset_key_bindings()`, `get_key_binding()`.

## Offen

- Feinschliff am PC: Größen, Abstände und Farben lassen sich nur am Bildschirm beurteilen.
  Das Layout ist für 1920 × 1080 gebaut und skaliert mit (Streckmodus `canvas_items`).
- Keine eigene Schrift (Godot-Standardschrift), keine Klänge für Klicks und Fenster.
- Kein Vergleich von Aspekten im Tooltip (nur Werte), kein Beutefilter, keine Truhe (Stash).
- Abklingzeit der Ausweichrolle (`Player.get_dodge_cooldown_left()`) und Statuseffekte
  (`status_effect_changed`) zeigt das HUD noch nicht.
- Die Skillleiste zeigt Beispieldaten nur in `ui_test`; im echten Spiel bleibt sie leer, bis AP5
  die Signale sendet.
