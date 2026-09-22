class_name LootBeam
extends Node3D
## Lichtsäule über Beute am Boden (AP1). Höhe und Stärke nach Seltenheit: Magisch glimmt nur,
## Selten hat eine kurze Säule, Legendär und Einzigartig eine hohe, weithin sichtbare.

const BEAM_SHADER := preload("res://graphics/shaders/loot_beam.gdshader")
## Seltenheit → [Säulenhöhe (0 = keine), Lichtenergie, Partikel].
const LOOKS: Dictionary[Enums.Rarity, Array] = {
	Enums.Rarity.MAGIC: [0.0, 0.6, 0],
	Enums.Rarity.RARE: [3.0, 1.2, 6],
	Enums.Rarity.LEGENDARY: [9.0, 2.2, 14],
	Enums.Rarity.UNIQUE: [11.0, 2.6, 18],
}

var item: ItemInstance
var rarity: Enums.Rarity = Enums.Rarity.NORMAL

var _beam: MeshInstance3D
var _glow: MeshInstance3D
var _light: OmniLight3D
var _particles: GPUParticles3D
var _age: float = 0.0


## Ob eine Seltenheit überhaupt ein Leuchten bekommt.
static func wants_beam(p_rarity: Enums.Rarity) -> bool:
	return LOOKS.has(p_rarity)


func setup(p_item: ItemInstance, p_rarity: Enums.Rarity) -> void:
	item = p_item
	rarity = p_rarity
	var look: Array = LOOKS.get(rarity, [0.0, 0.5, 0])
	var color := ItemText.rarity_color(rarity)
	var height: float = look[0]
	if height > 0.0:
		_beam = MeshInstance3D.new()
		_beam.name = "Beam"
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.06
		mesh.bottom_radius = 0.16
		mesh.height = height
		mesh.cap_top = false
		mesh.cap_bottom = false
		mesh.radial_segments = 16
		mesh.rings = 1
		_beam.mesh = mesh
		_beam.position = Vector3(0, height * 0.5, 0)
		var material := ShaderMaterial.new()
		material.shader = BEAM_SHADER
		material.set_shader_parameter(&"beam_color", color)
		material.set_shader_parameter(
			&"intensity", 1.1 if rarity >= Enums.Rarity.LEGENDARY else 0.8
		)
		_beam.material_override = material
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_beam)
	_glow = MeshInstance3D.new()
	_glow.name = "Glow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.8, 1.8)
	_glow.mesh = plane
	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_material.albedo_texture = ParticleFactory.soft_dot()
	glow_material.albedo_color = Color(color.r, color.g, color.b, 0.8)
	_glow.material_override = glow_material
	_glow.position = Vector3(0, 0.04, 0)
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.set_meta(&"ap1_loot", true)
	_light.light_color = color
	_light.light_energy = look[1]
	_light.omni_range = 3.5
	_light.position = Vector3(0, 0.8, 0)
	_light.shadow_enabled = false
	add_child(_light)
	if look[2] > 0:
		_particles = ParticleFactory.embers(0.6, look[2])
		_particles.name = "Motes"
		var process := _particles.process_material.duplicate() as ParticleProcessMaterial
		process.color_ramp = ParticleFactory.ramp(
			[Color(color.r, color.g, color.b, 0.0), color, Color(color.r, color.g, color.b, 0.0)]
		)
		_particles.process_material = process
		add_child(_particles)


func _process(delta: float) -> void:
	_age += delta
	# Kurzes Aufleuchten beim Fallen, danach ruhiges Pulsieren.
	var drop := maxf(0.0, 1.0 - _age / 0.6)
	if _light != null:
		var look: Array = LOOKS.get(rarity, [0.0, 0.5, 0])
		_light.light_energy = look[1] * (1.0 + drop * 2.0 + 0.12 * sin(_age * 3.0))
	if _beam != null:
		(_beam.material_override as ShaderMaterial).set_shader_parameter(&"pulse", drop * 1.5)
