extends GutTest
## AP1: Grafikstufen setzen die erwarteten Einstellungen.

var _saved_quality: int


func before_each() -> void:
	_saved_quality = Settings.quality


func after_each() -> void:
	Settings.quality = _saved_quality as Settings.Quality
	Graphics.apply_quality(_saved_quality)


func test_four_presets_with_names() -> void:
	assert_eq(Graphics.presets.size(), 4)
	assert_eq(
		Graphics.get_quality_names(), PackedStringArray(["Niedrig", "Mittel", "Hoch", "Ultra"])
	)


func test_presets_get_more_expensive() -> void:
	var low := Graphics.get_preset(Settings.Quality.LOW)
	var high := Graphics.get_preset(Settings.Quality.HIGH)
	var ultra := Graphics.get_preset(Settings.Quality.ULTRA)
	assert_false(low.sdfgi)
	assert_false(low.volumetric_fog)
	assert_lt(low.render_scale, 1.0)
	assert_true(high.sdfgi)
	assert_true(high.volumetric_fog)
	assert_true(high.ssr)
	assert_eq(high.render_scale, 1.0)
	assert_true(ultra.ssil)
	assert_lt(low.max_shadow_lights, high.max_shadow_lights)
	assert_lt(high.max_shadow_lights, ultra.max_shadow_lights)
	assert_lt(low.particle_amount, ultra.particle_amount)


func test_apply_quality_sets_viewport() -> void:
	Graphics.apply_quality(Settings.Quality.LOW)
	var viewport := Graphics.get_viewport()
	var low := Graphics.get_preset(Settings.Quality.LOW)
	assert_eq(viewport.msaa_3d, low.msaa_3d)
	assert_eq(viewport.scaling_3d_mode, low.scaling_3d_mode)
	assert_almost_eq(viewport.scaling_3d_scale, low.render_scale, 0.001)
	Graphics.apply_quality(Settings.Quality.ULTRA)
	assert_eq(viewport.msaa_3d, Viewport.MSAA_4X)
	assert_almost_eq(viewport.scaling_3d_scale, 1.0, 0.001)


func test_settings_change_applies_quality() -> void:
	watch_signals(Graphics)
	Settings.quality = Settings.Quality.MEDIUM
	Settings.apply()
	assert_eq(Graphics.quality, Settings.Quality.MEDIUM)
	assert_signal_emitted(Graphics, "quality_applied")


func test_environment_features_follow_quality() -> void:
	var env := Graphics.environment_for(&"catacombs")
	assert_not_null(env, "Katakomben-Umgebung vorhanden")
	env = env.duplicate() as Environment
	Graphics.apply_to_environment(env, Graphics.get_preset(Settings.Quality.LOW))
	assert_false(env.sdfgi_enabled)
	assert_false(env.volumetric_fog_enabled)
	assert_false(env.ssao_enabled)
	Graphics.apply_to_environment(env, Graphics.get_preset(Settings.Quality.HIGH))
	assert_true(env.sdfgi_enabled)
	assert_true(env.volumetric_fog_enabled)
	assert_true(env.ssr_enabled)
	assert_false(env.ssil_enabled, "SSIL nur auf Ultra")


func test_quality_never_enables_what_a_scene_left_off() -> void:
	var env := Environment.new()
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
	Graphics.apply_to_environment(env, Graphics.get_preset(Settings.Quality.ULTRA))
	assert_false(env.sdfgi_enabled)
	assert_false(env.volumetric_fog_enabled)


func test_all_themes_have_environments() -> void:
	for theme in [&"village", &"catacombs", &"boss"]:
		var env := Graphics.environment_for(theme)
		assert_not_null(env, String(theme))
		assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_AGX)
		assert_true(env.volumetric_fog_enabled)
		assert_not_null(env.adjustment_color_correction, "Farbkorrektur")


func test_light_presets_and_kinds() -> void:
	var torch := LightPresets.make(LightPresets.Kind.TORCH)
	autofree(torch)
	assert_not_null(torch.get_node_or_null("Flicker"))
	assert_not_null(torch.get_node_or_null("Flame"))
	assert_true(torch.distance_fade_enabled)
	var player_light := LightPresets.make_player_light()
	autofree(player_light)
	assert_false(player_light.shadow_enabled)
	assert_null(player_light.get_node_or_null("Flame"))
	var layout := World.generate(7, World.config_for_depth(1))
	var kinds := {}
	for position in layout.lights:
		kinds[LightPresets.kind_for(layout, position)] = true
	assert_true(kinds.has(LightPresets.Kind.TORCH), "Fackeln erkannt")
	var village := World.generate(0, World.config_for_depth(0))
	var village_kinds := {}
	for position in village.lights:
		village_kinds[LightPresets.kind_for(village, position)] = true
	assert_true(village_kinds.has(LightPresets.Kind.LAMP), "Laternen im Dorf")
	assert_true(village_kinds.has(LightPresets.Kind.ENTRANCE), "Licht am Gruft-Eingang")


func test_material_library_kinds() -> void:
	var wall := MaterialLibrary.get_material(&"stone_wall", Color(0.4, 0.4, 0.4))
	assert_true(wall is ShaderMaterial, "Wände blenden sich aus")
	assert_eq(MaterialLibrary.get_material(&"stone_wall", Color(0.4, 0.4, 0.4)), wall, "Cache")
	var floor_material := MaterialLibrary.get_material(&"stone_floor") as StandardMaterial3D
	assert_not_null(floor_material)
	assert_true(floor_material.normal_enabled)
	assert_not_null(floor_material.roughness_texture, "Pfützen für Spiegelungen")
	assert_eq(
		MaterialLibrary.kind_for_part(
			"wall", AABB(Vector3(-2, 0, -2), Vector3(4, 2.5, 4)), Color.GRAY
		),
		&"stone_wall"
	)
	assert_eq(
		MaterialLibrary.kind_for_part(
			"doorway", AABB(Vector3(-2, -0.2, -2), Vector3(4, 0.2, 4)), Color.GRAY
		),
		&"stone_floor"
	)
	assert_eq(MaterialLibrary.kind_for_part("ground_grass", AABB(), Color.GREEN), &"grass")
