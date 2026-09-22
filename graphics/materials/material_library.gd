class_name MaterialLibrary
extends RefCounted
## Materialbibliothek (AP1): PBR-Materialien mit prozedural erzeugten Texturen (Rauschen für
## Farbe, Normalen und Rauheit), damit auch Platzhalter-Blöcke nach Stein, Holz oder Erde aussehen.
##
## get_material(kind, tint) liefert ein geteiltes Material (Cache je Art und Farbton).
## Arten: siehe KINDS. Wände und Häuser nutzen den Shader occluding_surface.gdshader, der sich
## vor der Spielerfigur ausblendet.
## skin_placeholder_library() und make_occluding() passen ganze MeshLibraries an.

const OCCLUDING_SHADER := preload("res://graphics/shaders/occluding_surface.gdshader")
const DISSOLVE_SHADER := preload("res://graphics/shaders/dissolve.gdshader")
const HIT_FLASH_SHADER := preload("res://graphics/shaders/hit_flash.gdshader")

## Art → [Rauheit, Rauheit-Spielraum, Normalstärke, Rauschfrequenz, Metall, ausblendbar].
const KINDS: Dictionary[StringName, Array] = {
	&"stone_floor": [0.8, 0.75, 1.2, 0.008, 0.0, false],
	&"stone_wall": [0.9, 0.2, 1.6, 0.01, 0.0, true],
	&"rock": [0.9, 0.2, 2.0, 0.012, 0.0, true],
	&"plaster": [0.95, 0.1, 0.8, 0.015, 0.0, true],
	&"roof": [0.85, 0.15, 1.4, 0.03, 0.0, true],
	&"wood": [0.75, 0.25, 1.0, 0.03, 0.0, false],
	&"metal": [0.35, 0.3, 0.6, 0.02, 0.9, false],
	&"bone": [0.6, 0.2, 0.6, 0.02, 0.0, false],
	&"cloth": [1.0, 0.0, 0.5, 0.03, 0.0, false],
	&"grass": [0.95, 0.05, 1.0, 0.02, 0.0, false],
	&"dirt": [0.9, 0.5, 1.2, 0.01, 0.0, false],
	&"cobble": [0.8, 0.6, 1.6, 0.012, 0.0, false],
	&"foliage": [0.9, 0.1, 1.2, 0.03, 0.0, false],
}

## Items, die sich vor der Figur ausblenden dürfen (Namen aus docs/pakete/AP6.md).
const OCCLUDING_ITEMS: PackedStringArray = [
	"wall",
	"wall_corner",
	"wall_corner_outer",
	"wall_double",
	"wall_end",
	"doorway",
	"pillar",
	"house_wall",
	"house_corner",
	"house_door",
	"house_roof",
	"crypt_entrance",
	"tree",
	"rock",
]

static var _cache: Dictionary[String, Material] = {}
static var _textures: Dictionary[String, Texture2D] = {}
static var _skinned: Dictionary[MeshLibrary, bool] = {}


## Material einer Art mit Farbton. Cache je Art und Farbton, also günstig.
static func get_material(kind: StringName, tint: Color = Color.WHITE) -> Material:
	var key := "%s/%s" % [kind, tint.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var spec: Array = KINDS.get(kind, KINDS[&"stone_floor"])
	var material: Material
	if spec[5]:
		material = _make_occluding(kind, tint, spec)
	else:
		material = _make_standard(kind, tint, spec)
	material.resource_name = String(kind)
	_cache[key] = material
	return material


## Leuchtendes Material (Feuer, Glut, Magie). energy als Emissions-Faktor.
static func get_emissive(color: Color, energy: float = 4.0) -> StandardMaterial3D:
	var key := "emissive/%s/%.2f" % [color.to_html(false), energy]
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy
		material.roughness = 1.0
		_cache[key] = material
	return _cache[key] as StandardMaterial3D


## Wandelt ein StandardMaterial3D in die ausblendbare Variante um (Farbe, Textur, Rauheit
## bleiben). Für die echte MeshLibrary von AP8, deren Wände eigene Texturen haben.
static func make_occluding(source: BaseMaterial3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OCCLUDING_SHADER
	material.set_shader_parameter(&"albedo_color", source.albedo_color)
	material.set_shader_parameter(&"triplanar", source.uv1_triplanar)
	if source.albedo_texture != null:
		material.set_shader_parameter(&"albedo_texture", source.albedo_texture)
	if source.normal_enabled and source.normal_texture != null:
		material.set_shader_parameter(&"normal_texture", source.normal_texture)
		material.set_shader_parameter(&"use_normal_texture", true)
		material.set_shader_parameter(&"normal_strength", source.normal_scale)
	if source.roughness_texture != null:
		material.set_shader_parameter(&"roughness_texture", source.roughness_texture)
	material.set_shader_parameter(&"roughness", source.roughness)
	material.set_shader_parameter(&"metallic", source.metallic)
	material.set_shader_parameter(&"grime_strength", 0.0)
	material.resource_name = source.resource_name
	return material


## Ersetzt die grauen Materialien des Platzhalter-Baukastens (AP6) durch Materialien aus der
## Bibliothek. Die Art ergibt sich aus Item-Name, Form und Farbe des Teils.
## Nur einmal je Bibliothek.
static func skin_placeholder_library(library: MeshLibrary) -> void:
	if library == null or _skinned.has(library):
		return
	_skinned[library] = true
	for id in library.get_item_list():
		var mesh := library.get_item_mesh(id) as ArrayMesh
		if mesh == null:
			continue
		var item_name := library.get_item_name(id)
		for surface in mesh.get_surface_count():
			var old := mesh.surface_get_material(surface) as BaseMaterial3D
			if old == null:
				continue
			if old.emission_enabled:
				mesh.surface_set_material(surface, get_emissive(old.emission, 5.0))
				continue
			var bounds := _surface_bounds(mesh, surface)
			var kind := kind_for_part(item_name, bounds, old.albedo_color)
			mesh.surface_set_material(
				surface, get_material(kind, _tint_for(kind, old.albedo_color))
			)


## Macht die Wände der echten Bibliothek (AP8) ausblendbar, ohne ihr Aussehen zu ändern.
static func make_library_occluding(library: MeshLibrary) -> void:
	if library == null or _skinned.has(library):
		return
	_skinned[library] = true
	for id in library.get_item_list():
		if not OCCLUDING_ITEMS.has(library.get_item_name(id)):
			continue
		var mesh := library.get_item_mesh(id)
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var old := mesh.surface_get_material(surface) as BaseMaterial3D
			if old != null:
				mesh.surface_set_material(surface, make_occluding(old))


## Art eines Platzhalter-Teils. bounds im Raum des Items.
static func kind_for_part(item_name: String, bounds: AABB, color: Color) -> StringName:
	var flat := bounds.size.y < 0.35 and bounds.position.y < 0.05
	match item_name:
		"ground_grass":
			return &"grass"
		"ground_path":
			return &"cobble"
		"ground_dirt":
			return &"dirt"
		"house_roof":
			return &"roof"
		"tree":
			return &"foliage" if color.g > color.r else &"wood"
		"rock":
			return &"rock"
		"prop_bones", "prop_candles":
			return &"stone_floor" if flat else &"bone"
		"prop_banner":
			return &"cloth"
	if item_name.begins_with("house"):
		return &"plaster" if not _is_brown(color) else &"wood"
	if flat:
		return &"stone_floor"
	if _is_brown(color):
		return &"wood"
	if OCCLUDING_ITEMS.has(item_name):
		return &"stone_wall"
	if item_name == "brazier":
		return &"metal"
	return &"stone_floor"


## Rauschtextur für Farbe, Rauheit oder Normalen (nahtlos, 512 px). Cache je Parameter.
static func noise_texture(
	noise_seed: int,
	frequency: float,
	as_normal: bool = false,
	bump: float = 8.0,
	cellular: bool = false
) -> NoiseTexture2D:
	var key := "%d/%.3f/%s/%.1f/%s" % [noise_seed, frequency, as_normal, bump, cellular]
	if _textures.has(key):
		return _textures[key] as NoiseTexture2D
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.fractal_octaves = 5
	if cellular:
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	texture.generate_mipmaps = true
	if as_normal:
		texture.as_normal_map = true
		texture.bump_strength = bump
	_textures[key] = texture
	return texture


## Farbrauschen: Werte zwischen low und high (um 1.0), damit der Farbton der Art erhalten bleibt.
static func albedo_noise(
	noise_seed: int, frequency: float, low: float, high: float
) -> NoiseTexture2D:
	var key := "albedo/%d/%.3f/%.2f/%.2f" % [noise_seed, frequency, low, high]
	if _textures.has(key):
		return _textures[key] as NoiseTexture2D
	var texture := noise_texture(noise_seed, frequency).duplicate() as NoiseTexture2D
	var ramp := Gradient.new()
	ramp.set_color(0, Color(low, low, low))
	ramp.set_color(1, Color(high, high, high))
	texture.color_ramp = ramp
	_textures[key] = texture
	return texture


## Rauheitskarte mit Pfützen: dunkle Flecken sind glatt (spiegeln mit SSR), der Rest rau.
static func puddle_roughness(noise_seed: int, frequency: float, wetness: float) -> NoiseTexture2D:
	var key := "puddle/%d/%.3f/%.2f" % [noise_seed, frequency, wetness]
	if _textures.has(key):
		return _textures[key] as NoiseTexture2D
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5 - wetness * 0.3, 0.55, 1.0])
	ramp.colors = PackedColorArray(
		[Color(0.15, 0.15, 0.15), Color(0.2, 0.2, 0.2), Color(1, 1, 1), Color(0.9, 0.9, 0.9)]
	)
	texture.color_ramp = ramp
	_textures[key] = texture
	return texture


## Rauschtextur für den Auflöse-Shader.
static func dissolve_noise() -> NoiseTexture2D:
	return noise_texture(77, 0.02)


static func _make_standard(kind: StringName, tint: Color, spec: Array) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var seed_base := hash(kind) & 0xffff
	material.albedo_color = tint
	material.albedo_texture = albedo_noise(seed_base, spec[3], 0.72, 1.12)
	material.roughness = spec[0]
	material.metallic = spec[4]
	material.normal_enabled = true
	material.normal_scale = spec[2]
	material.normal_texture = noise_texture(
		seed_base + 1, spec[3] * 2.0, true, 6.0, kind == &"cobble" or kind == &"stone_floor"
	)
	if spec[1] > 0.3:
		material.roughness_texture = puddle_roughness(seed_base + 2, 0.004, spec[1] - 0.3)
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.35
	material.uv1_triplanar_sharpness = 4.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


static func _make_occluding(kind: StringName, tint: Color, spec: Array) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OCCLUDING_SHADER
	var seed_base := hash(kind) & 0xffff
	material.set_shader_parameter(&"albedo_color", tint)
	material.set_shader_parameter(&"albedo_texture", albedo_noise(seed_base, spec[3], 0.7, 1.15))
	material.set_shader_parameter(
		&"normal_texture", noise_texture(seed_base + 1, spec[3] * 2.0, true, 7.0, true)
	)
	material.set_shader_parameter(&"use_normal_texture", true)
	material.set_shader_parameter(&"normal_strength", spec[2])
	material.set_shader_parameter(&"roughness", spec[0])
	material.set_shader_parameter(&"metallic", spec[4])
	material.set_shader_parameter(&"triplanar", true)
	material.set_shader_parameter(&"triplanar_scale", 0.35)
	return material


static func _tint_for(kind: StringName, color: Color) -> Color:
	# Die Platzhalter sind sehr dunkel; die Texturen bringen eigene Helligkeit, darum leicht anheben.
	match kind:
		&"stone_floor", &"cobble":
			return color.lightened(0.12)
		&"stone_wall", &"rock":
			return color.lightened(0.08)
	return color


static func _is_brown(color: Color) -> bool:
	return color.r > color.g and color.g > color.b and color.r - color.b > 0.12


static func _surface_bounds(mesh: ArrayMesh, surface: int) -> AABB:
	var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return AABB()
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for vertex in vertices:
		bounds = bounds.expand(vertex)
	return bounds
