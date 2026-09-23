class_name LightPresets
extends RefCounted
## Licht-Vorlagen und Lichtregeln (AP1).
##
## Lichtregeln:
## - Wenige starke Lichtquellen mit Schatten (Fackeln, Feuerschalen nahe am Spieler),
##   alle anderen ohne Schatten. Wie viele Schatten werfen, legt die Grafikstufe fest
##   (QualityPreset.max_shadow_lights); Graphics wählt laufend die nächsten zum Spieler.
## - Warme Lichtinseln (Feuer) gegen kühles, schwaches Umgebungslicht.
## - Der Spieler trägt ein weiches Licht ohne Schatten, damit er im Dunkeln lesbar bleibt.
## - Lichter blenden aus der Ferne aus (distance_fade), damit große Ebenen günstig bleiben.

enum Kind { TORCH, BRAZIER, LAMP, ENTRANCE, PLAYER, LOOT, CANDLE }

## Art → [Farbe, Energie, Reichweite, Abfall, Nebel-Energie, Flammengröße (0 = keine)].
const PRESETS: Dictionary[Kind, Array] = {
	Kind.TORCH: [Color(1.0, 0.56, 0.24), 3.2, 9.0, 1.6, 1.4, 0.8],
	Kind.BRAZIER: [Color(1.0, 0.5, 0.2), 4.2, 12.0, 1.5, 1.8, 1.5],
	Kind.LAMP: [Color(1.0, 0.72, 0.42), 2.6, 11.0, 1.4, 1.2, 0.5],
	Kind.ENTRANCE: [Color(0.45, 0.75, 1.0), 3.5, 10.0, 1.3, 2.0, 0.0],
	Kind.PLAYER: [Color(1.0, 0.86, 0.7), 1.8, 9.0, 1.1, 0.3, 0.0],
	Kind.LOOT: [Color(1.0, 1.0, 1.0), 1.5, 4.0, 1.5, 0.6, 0.0],
	Kind.CANDLE: [Color(1.0, 0.62, 0.3), 0.9, 3.8, 1.8, 0.4, 0.0],
}

const PLAYER_LIGHT_NAME := &"AP1PlayerLight"
const PLAYER_LIGHT_HEIGHT := 3.4
const FADE_BEGIN := 40.0
const FADE_LENGTH := 12.0


## Stellt ein vorhandenes OmniLight3D auf eine Vorlage ein. flames: Flammen-Partikel anhängen.
static func configure(light: OmniLight3D, kind: Kind, flames: bool = true) -> OmniLight3D:
	var spec: Array = PRESETS[kind]
	light.light_color = spec[0]
	light.light_energy = spec[1]
	light.omni_range = spec[2]
	light.omni_attenuation = spec[3]
	light.light_volumetric_fog_energy = spec[4]
	light.light_indirect_energy = 1.2
	light.light_specular = 0.6
	light.shadow_bias = 0.08
	light.shadow_normal_bias = 1.5
	light.shadow_blur = 1.5
	light.distance_fade_enabled = true
	light.distance_fade_begin = FADE_BEGIN
	light.distance_fade_length = FADE_LENGTH
	light.distance_fade_shadow = 25.0
	light.set_meta(&"ap1_kind", kind)
	var flickering := [Kind.TORCH, Kind.BRAZIER, Kind.LAMP, Kind.CANDLE]
	if kind in flickering and light.get_node_or_null("Flicker") == null:
		var flicker := LightFlicker.new()
		flicker.name = "Flicker"
		flicker.amount = 0.22 if kind in [Kind.TORCH, Kind.CANDLE] else 0.14
		flicker.base_energy = spec[1]
		light.add_child(flicker)
	if flames and spec[5] > 0.0 and light.get_node_or_null("Flame") == null:
		var flame := ParticleFactory.flame(spec[5], 16 if kind == Kind.TORCH else 24)
		flame.position = Vector3(0, -0.15, 0) * spec[5]
		light.add_child(flame)
		var embers := ParticleFactory.embers(spec[5], 4 if kind == Kind.TORCH else 10)
		embers.position = flame.position
		light.add_child(embers)
	return light


## Neues Licht nach Vorlage.
static func make(kind: Kind, flames: bool = true) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = String(Kind.keys()[kind]).capitalize()
	return configure(light, kind, flames)


## Weiches Licht über dem Spieler. Wird als Kind der Spielerfigur eingesetzt.
static func make_player_light() -> OmniLight3D:
	var light := make(Kind.PLAYER, false)
	light.name = PLAYER_LIGHT_NAME
	light.position = Vector3(0, PLAYER_LIGHT_HEIGHT, 0.6)
	light.shadow_enabled = false
	light.distance_fade_enabled = false
	return light


## Art eines Level-Lichts aus der Requisite in seiner Zelle (Fackel, Feuerschale, Laterne,
## Gruft-Eingang). Unbekannt = Fackel.
static func kind_for(layout: LevelLayout, position: Vector3) -> Kind:
	if layout == null:
		return Kind.TORCH
	var size := layout.cell_size
	var cell := Vector3i(floori(position.x / size.x), 0, floori(position.z / size.z))
	var prop: int = layout.props.get(cell, -1)
	match prop:
		WorldTiles.Id.BRAZIER:
			return Kind.BRAZIER
		WorldTiles.Id.LAMP_POST:
			return Kind.LAMP
		WorldTiles.Id.TORCH_WALL:
			return Kind.TORCH
	if layout.cells.get(cell, -1) == WorldTiles.Id.CRYPT_ENTRANCE:
		return Kind.ENTRANCE
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var near := cell + Vector3i(dx, 0, dz)
			if layout.cells.get(near, -1) == WorldTiles.Id.CRYPT_ENTRANCE:
				return Kind.ENTRANCE
	return Kind.TORCH
