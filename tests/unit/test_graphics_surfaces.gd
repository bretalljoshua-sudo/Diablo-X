extends GutTest
## AP1: Detail-Oberflächen, Kleinkram am Boden, Kerzenlicht, Randlicht und Grafikstufe beim
## ersten Start.

var _saved_quality: int


func before_each() -> void:
	_saved_quality = Settings.quality


func after_each() -> void:
	MaterialLibrary.set_kit_detail(true)
	Settings.quality = _saved_quality as Settings.Quality
	Graphics.apply_quality(_saved_quality)


func test_recommended_quality_by_gpu() -> void:
	var discrete := RenderingDevice.DEVICE_TYPE_DISCRETE_GPU
	assert_eq(
		Graphics.recommended_quality("NVIDIA GeForce RTX 5080", discrete), Settings.Quality.ULTRA
	)
	assert_eq(
		Graphics.recommended_quality("NVIDIA GeForce RTX 4090", discrete), Settings.Quality.ULTRA
	)
	assert_eq(
		Graphics.recommended_quality("AMD Radeon RX 7900 XTX", discrete), Settings.Quality.ULTRA
	)
	assert_eq(
		Graphics.recommended_quality("NVIDIA GeForce RTX 3060", discrete), Settings.Quality.HIGH
	)
	assert_eq(
		Graphics.recommended_quality(
			"AMD Radeon Graphics", RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU
		),
		Settings.Quality.MEDIUM
	)
	assert_eq(Graphics.recommended_quality("llvmpipe", RenderingDevice.DEVICE_TYPE_CPU), -1)


func test_kit_material_follows_theme_and_detail() -> void:
	var source := StandardMaterial3D.new()
	source.albedo_color = Color(0.5, 0.4, 0.3)
	var material := MaterialLibrary.kit_material(source)
	assert_eq(material.shader, MaterialLibrary.KIT_SHADER)
	assert_eq(MaterialLibrary.kit_material(source), material, "Cache")
	assert_eq(
		MaterialLibrary.kit_material(StandardMaterial3D.new(), true).shader,
		MaterialLibrary.KIT_OCCLUDING_SHADER
	)
	assert_not_null(material.get_shader_parameter(&"stone_normal"))
	MaterialLibrary.set_kit_theme(&"catacombs")
	var wet_catacombs: float = material.get_shader_parameter(&"wetness")
	MaterialLibrary.set_kit_theme(&"village")
	assert_lt(material.get_shader_parameter(&"wetness"), wet_catacombs)
	Graphics.apply_quality(Settings.Quality.LOW)
	assert_false(material.get_shader_parameter(&"detail_enabled"), "Niedrig: flache Farben")
	Graphics.apply_quality(Settings.Quality.HIGH)
	assert_true(material.get_shader_parameter(&"detail_enabled"))


func test_real_kit_gets_detail_surfaces() -> void:
	if not WorldKit.uses_real_kit():
		pass_test("Nur Platzhalter-Baukasten vorhanden.")
		return
	var library := WorldKit.get_library()
	MaterialLibrary.dress_real_library(library)
	var kit := 0
	for item in library.get_item_list():
		var mesh := library.get_item_mesh(item)
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as ShaderMaterial
			if material != null and MaterialLibrary.get_kit_materials().has(material):
				kit += 1
	assert_gt(kit, 10, "Baukasten-Teile tragen den Detail-Shader")


func test_ground_clutter_in_village_and_catacombs() -> void:
	var village := World.generate(0, World.config_for_depth(0))
	var meadow := GroundClutter.build(village, 1.0)
	autofree(meadow)
	assert_not_null(meadow.grass, "Gras im Dorf")
	assert_gt(meadow.grass.multimesh.instance_count, 1000)
	assert_null(meadow.bones, "keine Knochen im Dorf")
	var catacombs := World.generate(7, World.config_for_depth(1))
	var dense := GroundClutter.build(catacombs, 1.0)
	var sparse := GroundClutter.build(catacombs, 0.35)
	var none := GroundClutter.build(catacombs, 0.0)
	autofree(dense)
	autofree(sparse)
	autofree(none)
	assert_null(dense.grass)
	assert_not_null(dense.rubble)
	assert_not_null(dense.bones)
	assert_gt(dense.decals.size(), 0, "Flecken und Risse")
	assert_lte(dense.decals.size(), GroundClutter.MAX_DECALS)
	assert_lt(sparse.instance_count(), dense.instance_count(), "Dichte folgt der Stufe")
	assert_eq(none.instance_count(), 0)
	var again := GroundClutter.build(catacombs, 1.0)
	autofree(again)
	assert_eq(
		again.pebbles.multimesh.get_instance_transform(3),
		dense.pebbles.multimesh.get_instance_transform(3),
		"gleicher Seed, gleiche Verteilung"
	)


func test_clutter_density_rises_with_quality() -> void:
	var low := Graphics.get_preset(Settings.Quality.LOW)
	var ultra := Graphics.get_preset(Settings.Quality.ULTRA)
	assert_lt(low.clutter_density, ultra.clutter_density)
	assert_false(low.surface_detail)
	assert_false(low.post_effects)
	assert_true(ultra.post_effects)
	assert_eq(ultra.directional_shadow_splits, 4)


func test_candle_lights_on_candle_props() -> void:
	var layout: LevelLayout
	for level_seed in range(1, 40):
		var candidate := World.generate(level_seed, World.config_for_depth(1))
		if candidate.props.values().has(WorldTiles.Id.PROP_CANDLES):
			layout = candidate
			break
	if layout == null:
		pass_test("Kein Kerzen-Requisit in den geprüften Ebenen.")
		return
	var candles := 0
	for id in layout.props.values():
		if id == WorldTiles.Id.PROP_CANDLES:
			candles += 1
	var level := Node3D.new()
	add_child_autofree(level)
	Graphics.add_candle_lights(level, layout)
	Graphics.add_candle_lights(level, layout)
	var holder := level.get_node("AP1Candles")
	assert_eq(holder.get_child_count(), candles, "ein Licht je Kerze, auch nach zweitem Aufruf")
	var light := holder.get_child(0) as OmniLight3D
	assert_false(light.shadow_enabled)
	assert_true(light.has_meta(&"ap1_candle"))


func test_rim_light_on_character_materials() -> void:
	var actor := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	mesh.material_override = material
	actor.add_child(mesh)
	add_child_autofree(actor)
	Graphics.add_rim_light(actor)
	assert_true(material.rim_enabled)
	assert_almost_eq(material.rim, Graphics.RIM_AMOUNT, 0.001)


func test_post_layer_sits_below_ui() -> void:
	var layer := Graphics.make_post_layer()
	autofree(layer)
	assert_lt(layer.layer, 0, "unter der Oberfläche")
	var rect := layer.get_node("Screen") as ColorRect
	assert_eq(rect.mouse_filter, Control.MOUSE_FILTER_IGNORE, "fängt keine Klicks ab")
	assert_eq((rect.material as ShaderMaterial).shader, Graphics.POST_SHADER)
