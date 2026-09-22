class_name ParticleFactory
extends RefCounted
## Bausteine für Partikeleffekte: weiche Punkt-Texturen, Billboard-Materialien, Farbverläufe.
## Alles prozedural, damit keine Bilddateien nötig sind.

static var _cache: Dictionary[String, Resource] = {}


## Weicher runder Fleck (Mitte hell, Rand durchsichtig).
static func soft_dot() -> GradientTexture2D:
	if not _cache.has("soft_dot"):
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		gradient.colors = PackedColorArray(
			[Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)]
		)
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		_cache["soft_dot"] = texture
	return _cache["soft_dot"] as GradientTexture2D


## Material für Partikel-Quads: Billboard, Vertexfarbe, additiv (Feuer, Funken, Magie)
## oder gemischt (Rauch, Blut, Staub).
static func billboard_material(additive: bool, energy: float = 1.0) -> StandardMaterial3D:
	var key := "bb/%s/%.2f" % [additive, energy]
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.billboard_keep_scale = true
		material.vertex_color_use_as_albedo = true
		material.albedo_texture = soft_dot()
		material.albedo_color = Color(energy, energy, energy, 1.0)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = (
			BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
		)
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		material.no_depth_test = false
		_cache[key] = material
	return _cache[key] as StandardMaterial3D


## Quad-Mesh mit Billboard-Material für GPUParticles3D.draw_pass_1.
static func quad(size: float, additive: bool, energy: float = 1.0) -> QuadMesh:
	var key := "quad/%.2f/%s/%.2f" % [size, additive, energy]
	if not _cache.has(key):
		var mesh := QuadMesh.new()
		mesh.size = Vector2(size, size)
		mesh.material = billboard_material(additive, energy)
		_cache[key] = mesh
	return _cache[key] as QuadMesh


## Farbverlauf über die Lebensdauer (Farben gleichmäßig verteilt).
static func ramp(colors: Array[Color]) -> GradientTexture1D:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / maxf(colors.size() - 1, 1))
	gradient.offsets = offsets
	gradient.colors = PackedColorArray(colors)
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


## Größenkurve über die Lebensdauer: start → peak (bei 20 %) → end.
static func size_curve(start: float, peak: float, end: float) -> CurveTexture:
	var curve := Curve.new()
	curve.max_value = maxf(maxf(start, peak), maxf(end, 1.0))
	curve.add_point(Vector2(0.0, start))
	curve.add_point(Vector2(0.2, peak))
	curve.add_point(Vector2(1.0, end))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


## Flamme für Fackeln und Feuerschalen (läuft dauerhaft).
static func flame(scale: float = 1.0, amount: int = 20) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Flame"
	particles.amount = amount
	particles.lifetime = 0.7
	particles.local_coords = false
	particles.draw_pass_1 = quad(0.35 * scale, true, 2.2)
	particles.visibility_aabb = AABB(Vector3(-1, -0.5, -1) * scale, Vector3(2, 3, 2) * scale)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.08 * scale
	process.direction = Vector3.UP
	process.spread = 12.0
	process.initial_velocity_min = 0.4 * scale
	process.initial_velocity_max = 0.9 * scale
	process.gravity = Vector3(0, 1.2 * scale, 0)
	process.damping_min = 0.5
	process.damping_max = 1.0
	process.scale_min = 0.7
	process.scale_max = 1.2
	process.scale_curve = size_curve(0.6, 1.0, 0.1)
	process.color_ramp = ramp(
		[
			Color(1.0, 0.9, 0.55, 1.0),
			Color(1.0, 0.55, 0.15, 0.9),
			Color(0.8, 0.2, 0.05, 0.5),
			Color(0.2, 0.05, 0.02, 0.0),
		]
	)
	particles.process_material = process
	return particles


## Glutfunken, die aus einem Feuer aufsteigen (läuft dauerhaft).
static func embers(scale: float = 1.0, amount: int = 8) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Embers"
	particles.amount = amount
	particles.lifetime = 1.8
	particles.local_coords = false
	particles.draw_pass_1 = quad(0.06 * scale, true, 3.0)
	particles.visibility_aabb = AABB(Vector3(-2, -0.5, -2) * scale, Vector3(4, 5, 4) * scale)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.15 * scale
	process.direction = Vector3.UP
	process.spread = 25.0
	process.initial_velocity_min = 0.6 * scale
	process.initial_velocity_max = 1.4 * scale
	process.gravity = Vector3(0, 0.3, 0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.8
	process.turbulence_noise_scale = 2.0
	process.color_ramp = ramp(
		[Color(1.0, 0.8, 0.4, 1.0), Color(1.0, 0.4, 0.1, 0.8), Color(0.6, 0.1, 0.0, 0.0)]
	)
	particles.process_material = process
	return particles
