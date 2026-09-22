class_name VfxLibrary
extends RefCounted
## Effekt-Bibliothek (AP1): baut Effekte aus Beschreibungen in SPECS. Ein neuer Effekt ist ein
## neuer Eintrag, kein neuer Code. Vfx.spawn(key, position) nimmt sie aus Pools.
##
## Effekt: {lifetime, emitters: [Emitter, …], light: [Farbe, Energie, Reichweite],
##          ring: [Farbe, Radius]}
## Emitter: amount, life, size, add (additiv), energy, colors, speed [min, max], spread,
##          gravity, dir, radius (Startkugel), shape ("sphere" oder "ring"), damping, explosive,
##          scale [Start, Spitze, Ende], up (Start über dem Boden)

const SPECS: Dictionary[StringName, Dictionary] = {
	# --- Treffer ---
	&"hit":
	{
		"lifetime": 0.6,
		"light": [Color(1.0, 0.8, 0.55), 2.0, 3.0],
		"emitters":
		[
			{
				"amount": 14,
				"life": 0.35,
				"size": 0.09,
				"add": true,
				"energy": 3.0,
				"colors": [Color(1, 0.95, 0.8, 1), Color(1, 0.6, 0.2, 1), Color(0.6, 0.2, 0.05, 0)],
				"speed": [4.0, 8.0],
				"spread": 55.0,
				"gravity": -12.0,
				"dir": Vector3(0, 0.4, -1),
				"damping": 2.0,
				"scale": [1.0, 1.0, 0.2],
			},
			{
				"amount": 3,
				"life": 0.14,
				"size": 0.9,
				"add": true,
				"energy": 2.0,
				"colors": [Color(1, 0.95, 0.85, 0.9), Color(1, 0.7, 0.4, 0)],
				"speed": [0.0, 0.1],
				"scale": [0.6, 1.2, 1.4],
			},
		],
	},
	&"blood":
	{
		"lifetime": 0.9,
		"emitters":
		[
			{
				"amount": 22,
				"life": 0.6,
				"size": 0.12,
				"add": false,
				"colors":
				[Color(0.45, 0.02, 0.02, 1), Color(0.25, 0.0, 0.0, 0.9), Color(0.15, 0, 0, 0)],
				"speed": [2.5, 6.0],
				"spread": 40.0,
				"gravity": -14.0,
				"dir": Vector3(0, 0.5, -1),
				"damping": 1.0,
				"scale": [0.8, 1.2, 0.5],
			},
			{
				"amount": 6,
				"life": 0.45,
				"size": 0.45,
				"add": false,
				"colors": [Color(0.35, 0.01, 0.01, 0.8), Color(0.2, 0, 0, 0)],
				"speed": [0.4, 1.2],
				"spread": 180.0,
				"gravity": -1.0,
				"scale": [0.5, 1.0, 1.3],
			},
		],
	},
	&"bone_chips":
	{
		"lifetime": 0.9,
		"emitters":
		[
			{
				"amount": 16,
				"life": 0.7,
				"size": 0.1,
				"add": false,
				"colors":
				[Color(0.85, 0.82, 0.72, 1), Color(0.6, 0.57, 0.5, 1), Color(0.4, 0.38, 0.33, 0)],
				"speed": [3.0, 6.0],
				"spread": 60.0,
				"gravity": -16.0,
				"dir": Vector3(0, 0.6, -1),
				"scale": [1.0, 1.0, 0.6],
			},
			{
				"amount": 6,
				"life": 0.6,
				"size": 0.6,
				"add": false,
				"colors": [Color(0.6, 0.58, 0.52, 0.5), Color(0.4, 0.38, 0.35, 0)],
				"speed": [0.3, 1.0],
				"spread": 180.0,
				"gravity": 0.3,
				"scale": [0.5, 1.0, 1.5],
			},
		],
	},
	&"sparks":
	{
		"lifetime": 0.7,
		"light": [Color(1.0, 0.75, 0.35), 3.0, 4.0],
		"emitters":
		[
			{
				"amount": 28,
				"life": 0.5,
				"size": 0.06,
				"add": true,
				"energy": 4.0,
				"colors": [Color(1, 1, 0.8, 1), Color(1, 0.7, 0.25, 1), Color(1, 0.3, 0.05, 0)],
				"speed": [6.0, 12.0],
				"spread": 70.0,
				"gravity": -18.0,
				"dir": Vector3(0, 0.5, -1),
				"damping": 1.0,
				"scale": [1.0, 1.0, 0.3],
			},
		],
	},
	&"fire_hit":
	{
		"lifetime": 0.9,
		"light": [Color(1.0, 0.5, 0.15), 3.5, 4.0],
		"emitters":
		[
			{
				"amount": 18,
				"life": 0.55,
				"size": 0.45,
				"add": true,
				"energy": 2.5,
				"colors":
				[Color(1, 0.85, 0.4, 1), Color(1, 0.4, 0.05, 0.8), Color(0.3, 0.05, 0, 0)],
				"speed": [1.0, 3.0],
				"spread": 180.0,
				"gravity": 3.0,
				"radius": 0.3,
				"scale": [0.4, 1.0, 0.2],
			},
		],
	},
	&"cold_hit":
	{
		"lifetime": 0.8,
		"light": [Color(0.5, 0.75, 1.0), 2.5, 3.5],
		"emitters":
		[
			{
				"amount": 20,
				"life": 0.6,
				"size": 0.12,
				"add": true,
				"energy": 2.5,
				"colors": [Color(0.9, 0.97, 1, 1), Color(0.5, 0.75, 1, 0.8), Color(0.2, 0.4, 1, 0)],
				"speed": [2.0, 5.0],
				"spread": 180.0,
				"gravity": -4.0,
				"scale": [1.0, 1.0, 0.3],
			},
		],
	},
	&"poison_hit":
	{
		"lifetime": 0.9,
		"emitters":
		[
			{
				"amount": 16,
				"life": 0.7,
				"size": 0.4,
				"add": false,
				"colors":
				[Color(0.4, 0.8, 0.2, 0.8), Color(0.2, 0.5, 0.1, 0.5), Color(0.1, 0.3, 0.05, 0)],
				"speed": [0.8, 2.5],
				"spread": 180.0,
				"gravity": 0.5,
				"radius": 0.3,
				"scale": [0.4, 1.0, 1.4],
			},
		],
	},
	&"crit":
	{
		"lifetime": 0.5,
		"light": [Color(1.0, 0.9, 0.6), 5.0, 5.0],
		"ring": [Color(1.0, 0.85, 0.5), 1.8],
		"emitters":
		[
			{
				"amount": 1,
				"life": 0.18,
				"size": 2.2,
				"add": true,
				"energy": 2.5,
				"colors": [Color(1, 0.95, 0.8, 1), Color(1, 0.8, 0.4, 0)],
				"speed": [0.0, 0.0],
				"scale": [0.4, 1.0, 1.2],
			},
		],
	},
	# --- Tod ---
	&"death_burst":
	{
		"lifetime": 2.0,
		"emitters":
		[
			{
				"amount": 20,
				"life": 1.4,
				"size": 0.8,
				"add": false,
				"colors":
				[Color(0.35, 0.32, 0.3, 0.6), Color(0.2, 0.19, 0.18, 0.3), Color(0.1, 0.1, 0.1, 0)],
				"speed": [0.5, 1.6],
				"spread": 180.0,
				"gravity": 0.2,
				"radius": 0.5,
				"damping": 1.0,
				"scale": [0.4, 1.0, 1.6],
				"up": 0.3,
			},
			{
				"amount": 14,
				"life": 1.6,
				"size": 0.08,
				"add": true,
				"energy": 3.0,
				"colors": [Color(1, 0.7, 0.3, 1), Color(1, 0.35, 0.1, 0.8), Color(0.5, 0.1, 0, 0)],
				"speed": [0.5, 1.5],
				"spread": 30.0,
				"gravity": 1.0,
				"dir": Vector3.UP,
				"radius": 0.5,
				"up": 0.8,
			},
		],
	},
	&"dust":
	{
		"lifetime": 1.2,
		"emitters":
		[
			{
				"amount": 10,
				"life": 1.0,
				"size": 0.7,
				"add": false,
				"colors": [Color(0.4, 0.37, 0.33, 0.5), Color(0.3, 0.28, 0.25, 0)],
				"speed": [0.5, 1.5],
				"spread": 90.0,
				"gravity": 0.2,
				"dir": Vector3.UP,
				"radius": 0.3,
				"scale": [0.4, 1.0, 1.8],
				"up": 0.1,
			},
		],
	},
	&"slam":
	{
		"lifetime": 1.4,
		"light": [Color(1.0, 0.7, 0.4), 5.0, 8.0],
		"ring": [Color(1.0, 0.75, 0.45), 4.5],
		"shake": [0.45, 0.35],
		"emitters":
		[
			{
				"amount": 36,
				"life": 1.1,
				"size": 1.0,
				"add": false,
				"colors":
				[Color(0.45, 0.4, 0.35, 0.7), Color(0.3, 0.28, 0.25, 0.4), Color(0.2, 0.2, 0.2, 0)],
				"speed": [3.0, 6.0],
				"spread": 12.0,
				"gravity": 0.0,
				"dir": Vector3(0, 0.15, -1),
				"shape": "ring",
				"radius": 0.8,
				"damping": 5.0,
				"scale": [0.4, 1.0, 1.8],
				"up": 0.2,
			},
			{
				"amount": 24,
				"life": 0.9,
				"size": 0.14,
				"add": false,
				"colors":
				[Color(0.35, 0.32, 0.3, 1), Color(0.25, 0.23, 0.2, 1), Color(0.2, 0.2, 0.2, 0)],
				"speed": [4.0, 8.0],
				"spread": 40.0,
				"gravity": -18.0,
				"dir": Vector3.UP,
				"radius": 1.0,
				"explosive": 1.0,
			},
		],
	},
	&"level_up":
	{
		"lifetime": 2.2,
		"light": [Color(1.0, 0.85, 0.4), 6.0, 8.0],
		"ring": [Color(1.0, 0.85, 0.4), 3.5],
		"emitters":
		[
			{
				"amount": 60,
				"life": 1.6,
				"size": 0.12,
				"add": true,
				"energy": 3.0,
				"colors": [Color(1, 0.95, 0.7, 1), Color(1, 0.8, 0.3, 0.8), Color(1, 0.6, 0.1, 0)],
				"speed": [2.0, 4.0],
				"spread": 8.0,
				"gravity": 0.5,
				"dir": Vector3.UP,
				"shape": "ring",
				"radius": 1.0,
			},
		],
	},
	# --- Krieger-Skills (Schlüssel in SkillDef.vfx_key, AP5) ---
	&"skill_strike":
	{
		"lifetime": 0.4,
		"emitters":
		[
			{
				"amount": 10,
				"life": 0.22,
				"size": 0.2,
				"add": true,
				"energy": 2.0,
				"colors": [Color(1, 0.95, 0.85, 0.8), Color(1, 0.8, 0.5, 0)],
				"speed": [6.0, 9.0],
				"spread": 50.0,
				"gravity": 0.0,
				"dir": Vector3(0, 0, -1),
				"damping": 10.0,
				"up": 1.0,
			},
		],
	},
	&"skill_cleave":
	{
		"lifetime": 0.6,
		"light": [Color(1.0, 0.6, 0.3), 3.0, 5.0],
		"emitters":
		[
			{
				"amount": 40,
				"life": 0.3,
				"size": 0.25,
				"add": true,
				"energy": 2.5,
				"colors": [Color(1, 0.9, 0.7, 0.9), Color(1, 0.5, 0.2, 0.6), Color(0.6, 0.1, 0, 0)],
				"speed": [7.0, 10.0],
				"spread": 70.0,
				"gravity": 0.0,
				"dir": Vector3(0, 0, -1),
				"damping": 12.0,
				"explosive": 1.0,
				"up": 1.0,
			},
		],
	},
	&"skill_whirlwind":
	{
		"lifetime": 0.7,
		"ring": [Color(0.9, 0.85, 0.8), 3.0],
		"emitters":
		[
			{
				"amount": 40,
				"life": 0.5,
				"size": 0.5,
				"add": false,
				"colors": [Color(0.5, 0.47, 0.42, 0.5), Color(0.35, 0.33, 0.3, 0)],
				"speed": [2.0, 4.0],
				"spread": 10.0,
				"gravity": 0.5,
				"dir": Vector3(0, 0.1, -1),
				"shape": "ring",
				"radius": 1.8,
				"scale": [0.4, 1.0, 1.5],
				"up": 0.3,
			},
			{
				"amount": 30,
				"life": 0.3,
				"size": 0.15,
				"add": true,
				"energy": 2.0,
				"colors": [Color(1, 0.95, 0.85, 0.8), Color(0.9, 0.8, 0.7, 0)],
				"speed": [3.0, 5.0],
				"spread": 20.0,
				"gravity": 0.0,
				"shape": "ring",
				"radius": 2.0,
				"up": 1.0,
			},
		],
	},
	&"skill_war_cry":
	{
		"lifetime": 1.2,
		"light": [Color(1.0, 0.4, 0.2), 6.0, 10.0],
		"ring": [Color(1.0, 0.45, 0.2), 7.0],
		"shake": [0.35, 0.3],
		"emitters":
		[
			{
				"amount": 50,
				"life": 0.9,
				"size": 0.12,
				"add": true,
				"energy": 1.4,
				"colors": [Color(1, 0.8, 0.5, 1), Color(1, 0.35, 0.1, 0.8), Color(0.6, 0.1, 0, 0)],
				"speed": [5.0, 8.0],
				"spread": 8.0,
				"gravity": 0.0,
				"dir": Vector3(0, 0.1, -1),
				"shape": "ring",
				"radius": 0.6,
				"damping": 3.0,
				"up": 1.0,
			},
		],
	},
	&"skill_leap":
	{
		"lifetime": 1.4,
		"light": [Color(1.0, 0.7, 0.4), 5.0, 8.0],
		"ring": [Color(1.0, 0.75, 0.45), 5.0],
		"shake": [0.55, 0.4],
		"emitters":
		[
			{
				"amount": 40,
				"life": 1.1,
				"size": 1.1,
				"add": false,
				"colors":
				[Color(0.45, 0.4, 0.35, 0.7), Color(0.3, 0.28, 0.25, 0.4), Color(0.2, 0.2, 0.2, 0)],
				"speed": [3.5, 7.0],
				"spread": 12.0,
				"gravity": 0.0,
				"dir": Vector3(0, 0.15, -1),
				"shape": "ring",
				"radius": 0.8,
				"damping": 5.0,
				"scale": [0.4, 1.0, 1.8],
				"up": 0.2,
			},
			{
				"amount": 30,
				"life": 0.9,
				"size": 0.14,
				"add": false,
				"colors":
				[Color(0.35, 0.32, 0.3, 1), Color(0.25, 0.23, 0.2, 1), Color(0.2, 0.2, 0.2, 0)],
				"speed": [4.0, 9.0],
				"spread": 40.0,
				"gravity": -18.0,
				"dir": Vector3.UP,
				"radius": 1.0,
				"explosive": 1.0,
			},
		],
	},
	&"skill_charge":
	{
		"lifetime": 1.0,
		"emitters":
		[
			{
				"amount": 30,
				"life": 0.8,
				"size": 0.8,
				"add": false,
				"colors": [Color(0.42, 0.38, 0.33, 0.6), Color(0.3, 0.28, 0.25, 0)],
				"speed": [0.5, 2.0],
				"spread": 60.0,
				"gravity": 0.3,
				"dir": Vector3(0, 0.3, 1),
				"radius": 0.4,
				"scale": [0.4, 1.0, 1.6],
				"up": 0.2,
			},
		],
	},
	&"skill_ancients":
	{
		"lifetime": 2.5,
		"light": [Color(1.0, 0.8, 0.45), 8.0, 12.0],
		"ring": [Color(1.0, 0.8, 0.45), 8.0],
		"shake": [0.7, 0.5],
		"emitters":
		[
			{
				"amount": 80,
				"life": 1.8,
				"size": 0.2,
				"add": true,
				"energy": 3.0,
				"colors":
				[Color(1, 0.95, 0.75, 1), Color(1, 0.75, 0.35, 0.8), Color(0.8, 0.4, 0.1, 0)],
				"speed": [3.0, 6.0],
				"spread": 6.0,
				"gravity": 0.0,
				"dir": Vector3.UP,
				"shape": "ring",
				"radius": 2.5,
			},
			{
				"amount": 40,
				"life": 1.2,
				"size": 1.2,
				"add": false,
				"colors": [Color(0.45, 0.4, 0.35, 0.6), Color(0.3, 0.28, 0.25, 0)],
				"speed": [3.0, 6.0],
				"spread": 12.0,
				"gravity": 0.0,
				"dir": Vector3(0, 0.1, -1),
				"shape": "ring",
				"radius": 1.0,
				"damping": 4.0,
				"scale": [0.4, 1.0, 1.8],
				"up": 0.2,
			},
		],
	},
	# Ein Einschlag der Ahnen am Zielpunkt (AP5 ruft ihn pro Schlag über Vfx.spawn auf).
	# Feuerring um den Krieger (Aspekt, AP5 ruft ihn jede Sekunde auf).
	&"skill_fire_ring":
	{
		"lifetime": 1.1,
		"light": [Color(1.0, 0.45, 0.15), 3.0, 7.0],
		"emitters":
		[
			{
				"amount": 70,
				"life": 0.8,
				"size": 0.45,
				"add": true,
				"energy": 2.5,
				"colors":
				[Color(1, 0.8, 0.4, 0.9), Color(1, 0.4, 0.1, 0.7), Color(0.4, 0.05, 0, 0)],
				"speed": [0.6, 1.6],
				"spread": 15.0,
				"gravity": 1.5,
				"dir": Vector3.UP,
				"shape": "ring",
				"radius": 3.2,
				"scale": [1.0, 0.8, 0.2],
			},
		],
	},
	&"skill_ancients_strike":
	{
		"lifetime": 1.2,
		"light": [Color(1.0, 0.8, 0.45), 5.0, 8.0],
		"ring": [Color(1.0, 0.8, 0.45), 4.0],
		"emitters":
		[
			{
				"amount": 30,
				"life": 0.6,
				"size": 0.16,
				"add": true,
				"energy": 3.0,
				"colors":
				[Color(1, 0.95, 0.75, 1), Color(1, 0.7, 0.3, 0.7), Color(0.8, 0.4, 0.1, 0)],
				"speed": [4.0, 8.0],
				"spread": 35.0,
				"gravity": -6.0,
				"dir": Vector3.UP,
				"radius": 0.6,
				"explosive": 1.0,
			},
			{
				"amount": 24,
				"life": 1.0,
				"size": 1.0,
				"add": false,
				"colors": [Color(0.45, 0.4, 0.35, 0.6), Color(0.3, 0.28, 0.25, 0)],
				"speed": [2.5, 5.0],
				"spread": 12.0,
				"gravity": 0.0,
				"dir": Vector3(0, 0.1, -1),
				"shape": "ring",
				"radius": 0.8,
				"damping": 4.0,
				"scale": [0.4, 1.0, 1.6],
				"up": 0.2,
			},
		],
	},
}

static var _ring_cache: GradientTexture2D


static func has_effect(key: StringName) -> bool:
	return SPECS.has(key)


## Baut einen neuen Effekt. particle_amount: Faktor aus der Grafikstufe.
static func build(key: StringName, particle_amount: float = 1.0) -> VfxEffect:
	var spec: Dictionary = SPECS.get(key, SPECS[&"hit"])
	var effect := VfxEffect.new()
	effect.name = "Vfx_%s" % key
	effect.key = key
	effect.lifetime = spec.get("lifetime", 1.0)
	for emitter_spec: Dictionary in spec.get("emitters", []):
		var emitter := build_emitter(emitter_spec, particle_amount)
		effect.add_child(emitter)
		effect.emitters.append(emitter)
	if spec.has("light"):
		var light_spec: Array = spec["light"]
		var light := OmniLight3D.new()
		light.name = "Flash"
		light.light_color = light_spec[0]
		light.omni_range = light_spec[2]
		light.position = Vector3(0, 1.0, 0)
		light.shadow_enabled = false
		# Sonst leuchtet der Volumennebel um den Blitz wie eine Kugel.
		light.light_volumetric_fog_energy = 0.15
		light.visible = false
		effect.add_child(light)
		effect.flash_light = light
		effect.flash_energy = light_spec[1]
	if spec.has("ring"):
		var ring_spec: Array = spec["ring"]
		var ring := MeshInstance3D.new()
		ring.name = "Ring"
		ring.mesh = _ring_mesh()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.albedo_texture = _ring_texture()
		var ring_color: Color = ring_spec[0]
		ring_color.a = 0.55
		material.albedo_color = ring_color
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position = Vector3(0, 0.06, 0)
		ring.visible = false
		effect.add_child(ring)
		effect.ring = ring
		effect.ring_radius = ring_spec[1]
	return effect


## Kamerawackeln eines Effekts: [Stärke, Dauer] oder leer.
static func shake_for(key: StringName) -> Array:
	return SPECS.get(key, {}).get("shake", [])


static func build_emitter(spec: Dictionary, particle_amount: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = maxi(1, roundi(spec.get("amount", 10) * particle_amount))
	particles.lifetime = spec.get("life", 0.5)
	particles.one_shot = true
	particles.explosiveness = spec.get("explosive", 0.9)
	particles.emitting = false
	particles.local_coords = false
	particles.fixed_fps = 0
	particles.position = Vector3(0, spec.get("up", 0.9), 0)
	particles.visibility_aabb = AABB(Vector3(-6, -2, -6), Vector3(12, 8, 12))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.draw_pass_1 = ParticleFactory.quad(
		spec.get("size", 0.2), spec.get("add", true), spec.get("energy", 1.0)
	)
	var process := ParticleProcessMaterial.new()
	var radius: float = spec.get("radius", 0.1)
	if spec.get("shape", "sphere") == "ring":
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		process.emission_ring_axis = Vector3.UP
		process.emission_ring_radius = radius
		process.emission_ring_inner_radius = radius * 0.9
		process.emission_ring_height = 0.1
		# Ring: Partikel fliegen radial nach außen.
		process.radial_velocity_min = spec.get("speed", [1.0, 2.0])[0]
		process.radial_velocity_max = spec.get("speed", [1.0, 2.0])[1]
		process.initial_velocity_min = 0.0
		process.initial_velocity_max = 0.5
		process.direction = Vector3.UP
	else:
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		process.emission_sphere_radius = radius
		process.direction = spec.get("dir", Vector3.UP)
		process.initial_velocity_min = spec.get("speed", [1.0, 2.0])[0]
		process.initial_velocity_max = spec.get("speed", [1.0, 2.0])[1]
	process.spread = spec.get("spread", 30.0)
	process.gravity = Vector3(0, spec.get("gravity", -9.8), 0)
	process.damping_min = spec.get("damping", 0.0) * 0.7
	process.damping_max = spec.get("damping", 0.0)
	process.scale_min = 0.7
	process.scale_max = 1.3
	var curve: Array = spec.get("scale", [1.0, 1.0, 0.3])
	process.scale_curve = ParticleFactory.size_curve(curve[0], curve[1], curve[2])
	var colors: Array[Color] = []
	for color: Color in spec.get("colors", [Color.WHITE, Color(1, 1, 1, 0)]):
		colors.append(color)
	process.color_ramp = ParticleFactory.ramp(colors)
	process.angle_min = -180.0
	process.angle_max = 180.0
	particles.process_material = process
	return particles


static func _ring_mesh() -> PlaneMesh:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2, 2)
	return mesh


static func _ring_texture() -> GradientTexture2D:
	if _ring_cache != null:
		return _ring_cache
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.8, 0.93, 1.0])
	gradient.colors = PackedColorArray(
		[Color(1, 1, 1, 0), Color(1, 1, 1, 0.05), Color(1, 1, 1, 1), Color(1, 1, 1, 0)]
	)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	_ring_cache = texture
	return texture
