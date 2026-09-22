extends Node
## Autoload „Graphics“ (AP1): Grafikstufen, Umgebungen je Ebene, Licht-Vorlagen, Materialien,
## Spielerlicht, schwebender Staub und das Ausblenden verdeckender Wände.
##
## Andere Pakete müssen nichts aufrufen: Graphics hört auf Settings.changed (Grafikstufe),
## EventBus.level_loaded (Licht, Materialien, Umgebung) und beobachtet Game.player.
## Das Menü (AP7) setzt Settings.quality und ruft Settings.apply().

signal quality_applied(quality: int)

const QUALITY_PATH := "res://graphics/quality/%s.tres"
const QUALITY_FILES: PackedStringArray = ["low", "medium", "high", "ultra"]
const ENVIRONMENT_PATH := "res://graphics/environments/%s.tres"
## Radius um die Figur, in dem verdeckende Wände ausgeblendet werden (Meter, im Bild).
const OCCLUSION_RADIUS := 2.6
## Höhe über den Füßen der Figur, auf die das Ausblenden zielt.
const OCCLUSION_HEIGHT := 1.0
const SHADOW_UPDATE_SEC := 0.4
const DUST_NAME := &"AP1Dust"

## Aktive Grafikstufe (Settings.Quality).
var quality: int = -1
var presets: Array[QualityPreset] = []
## Ausblenden verdeckender Wände an oder aus.
var occlusion_enabled: bool = true

var _level_lights: Array[OmniLight3D] = []
var _shadow_timer: float = 0.0
var _decorated_player: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	presets = load_presets()
	Settings.changed.connect(_on_settings_changed)
	EventBus.level_loaded.connect(_on_level_loaded)
	EventBus.level_unloading.connect(func(_layout: LevelLayout) -> void: _level_lights.clear())
	Game.scene_changed.connect(func(_name: String) -> void: _apply_to_scene.call_deferred())
	apply_quality(Settings.quality)


func _process(delta: float) -> void:
	var player := Game.player
	if is_instance_valid(player) and player.is_inside_tree():
		if player != _decorated_player:
			decorate_player(player)
		var radius := OCCLUSION_RADIUS if occlusion_enabled else 0.0
		RenderingServer.global_shader_parameter_set(&"occlusion_radius", radius)
		RenderingServer.global_shader_parameter_set(
			&"occlusion_target", player.global_position + Vector3(0, OCCLUSION_HEIGHT, 0)
		)
	else:
		RenderingServer.global_shader_parameter_set(&"occlusion_radius", 0.0)
	_shadow_timer -= delta
	if _shadow_timer <= 0.0:
		_shadow_timer = SHADOW_UPDATE_SEC
		update_shadow_lights()


## Lädt die vier Grafikstufen aus graphics/quality/, fehlende werden im Code ergänzt.
static func load_presets() -> Array[QualityPreset]:
	var result: Array[QualityPreset] = []
	for i in QUALITY_FILES.size():
		var path := QUALITY_PATH % QUALITY_FILES[i]
		var preset: QualityPreset = null
		if ResourceLoader.exists(path):
			preset = load(path) as QualityPreset
		if preset == null:
			preset = QualityPreset.new()
			preset.display_name = QUALITY_FILES[i]
		result.append(preset)
	return result


## Namen der Stufen für Menüs, Reihenfolge wie Settings.Quality.
func get_quality_names() -> PackedStringArray:
	var names := PackedStringArray()
	for preset in presets:
		names.append(preset.display_name)
	return names


func get_preset(level: int = -1) -> QualityPreset:
	if level < 0:
		level = quality if quality >= 0 else Settings.quality
	return presets[clampi(level, 0, presets.size() - 1)]


## Setzt eine Grafikstufe auf Viewport, RenderingServer, Umgebungen und Lichter.
func apply_quality(level: int) -> void:
	quality = clampi(level, 0, presets.size() - 1)
	var preset := get_preset(quality)
	apply_to_viewport(get_viewport(), preset)
	RenderingServer.directional_shadow_atlas_set_size(preset.directional_shadow_size, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(preset.soft_shadow_quality)
	RenderingServer.positional_soft_shadow_filter_set_quality(preset.soft_shadow_quality)
	RenderingServer.gi_set_use_half_resolution(preset.sdfgi_half_resolution)
	RenderingServer.environment_set_sdfgi_ray_count(preset.sdfgi_ray_count)
	RenderingServer.environment_set_ssao_quality(
		preset.ssao_quality, preset.ssao_half_size, 0.5, 2, 50.0, 300.0
	)
	RenderingServer.environment_set_ssil_quality(
		RenderingServer.ENV_SSIL_QUALITY_MEDIUM, true, 0.5, 4, 50.0, 300.0
	)
	RenderingServer.environment_set_volumetric_fog_volume_size(
		preset.volumetric_fog_size, preset.volumetric_fog_depth
	)
	RenderingServer.environment_glow_set_use_bicubic_upscale(preset.glow_bicubic)
	_apply_to_scene()
	quality_applied.emit(quality)


static func apply_to_viewport(viewport: Viewport, preset: QualityPreset) -> void:
	if viewport == null:
		return
	viewport.msaa_3d = preset.msaa_3d
	viewport.screen_space_aa = preset.screen_space_aa
	viewport.use_taa = preset.use_taa
	viewport.scaling_3d_mode = preset.scaling_3d_mode
	viewport.scaling_3d_scale = preset.render_scale
	viewport.fsr_sharpness = preset.fsr_sharpness
	viewport.mesh_lod_threshold = preset.mesh_lod_threshold
	viewport.positional_shadow_atlas_size = preset.positional_shadow_atlas_size


## Schaltet teure Effekte einer Umgebung nach der Grafikstufe ab. Was die Umgebung selbst nicht
## an hat, schaltet die Stufe nie ein (fremde Testszenen behalten ihren Look).
static func apply_to_environment(env: Environment, preset: QualityPreset) -> void:
	if env == null:
		return
	if not env.has_meta(&"ap1_base"):
		(
			env
			. set_meta(
				&"ap1_base",
				{
					"sdfgi": env.sdfgi_enabled,
					"ssao": env.ssao_enabled,
					"ssil": env.ssil_enabled,
					"ssr": env.ssr_enabled,
					"volumetric_fog": env.volumetric_fog_enabled,
					"glow": env.glow_enabled,
				}
			)
		)
	var base: Dictionary = env.get_meta(&"ap1_base")
	env.sdfgi_enabled = base["sdfgi"] and preset.sdfgi
	env.ssao_enabled = base["ssao"] and preset.ssao
	env.ssil_enabled = base["ssil"] and preset.ssil
	env.ssr_enabled = base["ssr"] and preset.ssr
	env.ssr_max_steps = preset.ssr_max_steps
	env.volumetric_fog_enabled = base["volumetric_fog"] and preset.volumetric_fog
	env.glow_enabled = base["glow"] and preset.glow


## Umgebung (Licht, Nebel, Farbkorrektur) für ein Thema der Welt, oder null.
static func environment_for(theme: StringName) -> Environment:
	var path := ENVIRONMENT_PATH % theme
	return load(path) as Environment if ResourceLoader.exists(path) else null


## Macht aus den Lichtern, Materialien und der Umgebung einer frisch gebauten Ebene den AP1-Look.
func decorate_level(level: Node, layout: LevelLayout) -> void:
	var preset := get_preset()
	var library := WorldKit.get_library()
	if WorldKit.uses_real_kit():
		MaterialLibrary.make_library_occluding(library)
	else:
		MaterialLibrary.skin_placeholder_library(library)
	_level_lights.clear()
	for node in level.find_children("*", "OmniLight3D", true, false):
		var light := node as OmniLight3D
		if light.name == LightPresets.PLAYER_LIGHT_NAME or light.has_meta(&"ap1_loot"):
			continue
		var kind := LightPresets.kind_for(layout, light.global_position)
		LightPresets.configure(light, kind, preset.light_flames)
		_level_lights.append(light)
	update_shadow_lights()
	_apply_to_scene()


## Hängt Spielerlicht und Staub an die Figur (einmal je Figur).
func decorate_player(player: Node3D) -> void:
	_decorated_player = player
	if player.get_node_or_null(NodePath(LightPresets.PLAYER_LIGHT_NAME)) == null:
		player.add_child(LightPresets.make_player_light())
	var dust := player.get_node_or_null(NodePath(DUST_NAME))
	if dust == null:
		dust = make_dust()
		player.add_child(dust)
	(dust as GPUParticles3D).emitting = get_preset().ambient_particles


## Schatten nur für die nächsten Lichter zum Spieler (Anzahl aus der Grafikstufe).
func update_shadow_lights() -> void:
	var alive: Array[OmniLight3D] = []
	for light: Variant in _level_lights:
		if is_instance_valid(light) and (light as OmniLight3D).is_inside_tree():
			alive.append(light)
	_level_lights = alive
	if _level_lights.is_empty():
		return
	var center := Vector3.ZERO
	if is_instance_valid(Game.player) and Game.player.is_inside_tree():
		center = Game.player.global_position
	else:
		var rig := CameraRig.get_active()
		if rig != null:
			center = rig.global_position
	var ordered := _level_lights.duplicate()
	ordered.sort_custom(
		func(a: OmniLight3D, b: OmniLight3D) -> bool:
			return (
				a.global_position.distance_squared_to(center)
				< b.global_position.distance_squared_to(center)
			)
	)
	var budget := get_preset().max_shadow_lights
	for i in ordered.size():
		(ordered[i] as OmniLight3D).shadow_enabled = i < budget


## Anzahl der Level-Lichter, die gerade Schatten werfen (für Tests und Anzeige).
func count_shadow_lights() -> int:
	var count := 0
	for light: Variant in _level_lights:
		if is_instance_valid(light) and (light as OmniLight3D).shadow_enabled:
			count += 1
	return count


## Schwebender Staub um die Figur (bleibt in der Welt stehen, während die Figur läuft).
static func make_dust() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = DUST_NAME
	particles.amount = 60
	particles.lifetime = 8.0
	particles.preprocess = 4.0
	particles.local_coords = false
	particles.draw_pass_1 = ParticleFactory.quad(0.05, true, 0.6)
	particles.visibility_aabb = AABB(Vector3(-14, -2, -14), Vector3(28, 10, 28))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(10, 2, 10)
	process.emission_shape_offset = Vector3(0, 2.2, 0)
	process.gravity = Vector3(0, -0.02, 0)
	process.initial_velocity_min = 0.02
	process.initial_velocity_max = 0.12
	process.spread = 180.0
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.3
	process.turbulence_noise_speed_random = 0.2
	process.scale_min = 0.5
	process.scale_max = 1.4
	process.color_ramp = ParticleFactory.ramp(
		[Color(1, 0.9, 0.75, 0.0), Color(1, 0.9, 0.75, 0.5), Color(1, 0.9, 0.75, 0.0)]
	)
	particles.process_material = process
	return particles


func _apply_to_scene() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var preset := get_preset()
	for node in tree.root.find_children("*", "WorldEnvironment", true, false):
		apply_to_environment((node as WorldEnvironment).environment, preset)
	for node in tree.root.find_children("*", "DirectionalLight3D", true, false):
		var sun := node as DirectionalLight3D
		sun.directional_shadow_max_distance = preset.directional_shadow_distance
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if is_instance_valid(_decorated_player):
		var dust := _decorated_player.get_node_or_null(NodePath(DUST_NAME)) as GPUParticles3D
		if dust != null:
			dust.emitting = preset.ambient_particles
	update_shadow_lights()


func _on_settings_changed() -> void:
	if Settings.quality != quality:
		apply_quality(Settings.quality)


func _on_level_loaded(layout: LevelLayout) -> void:
	var level := Level.get_active()
	if level != null:
		decorate_level(level, layout)
