class_name QualityPreset
extends Resource
## Einstellungen einer Grafikstufe (Niedrig, Mittel, Hoch, Ultra). Graphics.apply_quality()
## setzt sie auf Viewport, RenderingServer, Umgebungen und Lichter.
## Die Stufen liegen als graphics/quality/<stufe>.tres und lassen sich im Editor anpassen.

@export var display_name: String = ""

@export_group("Kantenglättung und Auflösung")
@export var msaa_3d: Viewport.MSAA = Viewport.MSAA_2X
@export var screen_space_aa: Viewport.ScreenSpaceAA = Viewport.SCREEN_SPACE_AA_DISABLED
@export var use_taa: bool = false
@export var scaling_3d_mode: Viewport.Scaling3DMode = Viewport.SCALING_3D_MODE_BILINEAR
## Anteil der Bildschirmauflösung, mit der die 3D-Welt gerendert wird (1.0 = voll).
@export_range(0.5, 2.0, 0.01) var render_scale: float = 1.0
@export_range(0.0, 2.0, 0.05) var fsr_sharpness: float = 0.2
## Schwelle für Detailstufen der Meshes (höher = früher gröber).
@export_range(0.0, 8.0, 0.1) var mesh_lod_threshold: float = 1.0

@export_group("Schatten")
@export var directional_shadow_size: int = 4096
@export var positional_shadow_atlas_size: int = 4096
@export
var soft_shadow_quality: RenderingServer.ShadowQuality = RenderingServer.SHADOW_QUALITY_SOFT_LOW
## Wie viele Fackeln und Feuer nahe am Spieler Schatten werfen.
@export var max_shadow_lights: int = 6
## Schattenweite der Richtungslichter (Mond) in Metern.
@export var directional_shadow_distance: float = 45.0

@export_group("Globale Beleuchtung und Bildeffekte")
@export var sdfgi: bool = false
@export var sdfgi_half_resolution: bool = true
@export var sdfgi_ray_count: RenderingServer.EnvironmentSDFGIRayCount = (
	RenderingServer.ENV_SDFGI_RAY_COUNT_32
)
@export var ssao: bool = true
@export
var ssao_quality: RenderingServer.EnvironmentSSAOQuality = RenderingServer.ENV_SSAO_QUALITY_MEDIUM
@export var ssao_half_size: bool = true
@export var ssil: bool = false
@export var ssr: bool = false
@export var ssr_max_steps: int = 48
@export var volumetric_fog: bool = false
@export var volumetric_fog_size: int = 96
@export var volumetric_fog_depth: int = 64
@export var glow: bool = true
@export var glow_bicubic: bool = false

@export_group("Effekte")
## Faktor auf die Partikelmenge der Effekte.
@export_range(0.1, 2.0, 0.05) var particle_amount: float = 1.0
## Höchstzahl gleichzeitiger Blut-Decals am Boden.
@export var max_decals: int = 48
## Flammen-Partikel an Fackeln und Feuerschalen.
@export var light_flames: bool = true
## Schwebender Staub in der Luft.
@export var ambient_particles: bool = true
