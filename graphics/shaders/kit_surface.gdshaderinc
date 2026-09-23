// Oberfläche für den Baukasten aus AP8 (KayKit): Farbe aus dem Paletten-Atlas des Modells,
// darüber weltbezogene Detail-Texturen (Stein oder Holz, je nach Grundfarbe), großflächiger
// Schmutz, Moos in Ritzen und am Boden und nasse Stellen auf dem Boden.
// Texturen: graphics/textures/ (erzeugt von graphics/tools/gen_detail_textures.py).
// Mit #define OCCLUDING vor dem include blendet sich die Fläche vor der Spielerfigur aus
// (wie occluding_surface.gdshader).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#ifdef OCCLUDING
global uniform vec3 occlusion_target;
global uniform float occlusion_radius;
uniform float occlusion_min_height = 0.35;
#endif

group_uniforms base;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 uv_scale = vec3(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

group_uniforms detail;
// Aus in der Grafikstufe „Niedrig“: dann nur die flache Farbe wie im Original.
uniform bool detail_enabled = true;
uniform sampler2D stone_detail : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wood_detail : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wood_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_noise : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// Kacheln pro Meter (0,45 = eine Kachel auf gut 2 m).
uniform float stone_scale = 0.45;
uniform float wood_scale = 0.7;
uniform float macro_scale = 0.045;
uniform float detail_strength : hint_range(0.0, 1.0) = 1.0;
uniform float normal_strength : hint_range(0.0, 3.0) = 1.6;
uniform float cavity_strength : hint_range(0.0, 1.0) = 0.7;
// 0 = Holz nie, 1 = Holz nach Grundfarbe erkennen.
uniform float wood_bias : hint_range(0.0, 1.0) = 1.0;

group_uniforms weathering;
// Werte je Gebiet, gesetzt von Graphics.decorate_level() über MaterialLibrary.set_kit_theme().
uniform float grime_amount : hint_range(0.0, 1.0) = 0.5;
uniform float grime_height = 1.2;
uniform vec4 moss_color : source_color = vec4(0.2, 0.26, 0.12, 1.0);
uniform float moss_amount : hint_range(0.0, 1.0) = 0.3;
uniform float wetness : hint_range(0.0, 1.0) = 0.3;
uniform float ground_y = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 tri_sample(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy) * w.x + texture(tex, p.xz) * w.y + texture(tex, p.xy) * w.z;
}

vec3 unpack_normal(vec4 c, float strength) {
	vec3 n = c.xyz * 2.0 - 1.0;
	// Grün zeigt im Bild nach oben, v wächst im Bild nach unten.
	n.y = -n.y;
	n.xy *= strength;
	return n;
}

// Triplanare Normalen mit „Whiteout“-Mischung (Ben Golus), Ergebnis in Weltkoordinaten.
vec3 tri_normal(sampler2D tex, vec3 p, vec3 n, vec3 w, float strength) {
	vec3 tx = unpack_normal(texture(tex, p.zy), strength);
	vec3 ty = unpack_normal(texture(tex, p.xz), strength);
	vec3 tz = unpack_normal(texture(tex, p.xy), strength);
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

#ifdef OCCLUDING
float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int index = i.x + i.y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[index] + 0.5) / 16.0;
}
#endif

void fragment() {
#ifdef OCCLUDING
	if (occlusion_radius > 0.0 && world_pos.y > occlusion_min_height) {
		vec3 target_view = (VIEW_MATRIX * vec4(occlusion_target, 1.0)).xyz;
		// Nur was näher an der Kamera liegt als die Figur, und nur im Kreis um sie herum.
		if (VERTEX.z > target_view.z + 0.6) {
			float d = length(VERTEX.xy - target_view.xy);
			float fade = 1.0 - smoothstep(occlusion_radius * 0.55, occlusion_radius, d);
			if (fade * 0.85 > bayer4(FRAGCOORD.xy)) {
				discard;
			}
		}
	}
#endif
	vec3 base = texture(albedo_texture, UV * uv_scale.xy).rgb * albedo_color.rgb;
	float rough = roughness;
	vec3 n = normalize(world_normal);
	if (detail_enabled) {
		vec3 w = pow(abs(n), vec3(4.0));
		w /= max(w.x + w.y + w.z, 0.0001);
		// Holz an warmer, nicht zu heller Grundfarbe erkennen, sonst Stein.
		float warm = base.r - base.b;
		float lum = dot(base, vec3(0.299, 0.587, 0.114));
		float wood = smoothstep(0.05, 0.15, warm) * (1.0 - smoothstep(0.5, 0.75, lum)) * wood_bias;
		vec3 ps = world_pos * stone_scale;
		vec4 d = tri_sample(stone_detail, ps, w);
		vec3 dn = tri_normal(stone_normal, ps, n, w, normal_strength);
		if (wood > 0.01) {
			vec3 pw = world_pos * wood_scale;
			d = mix(d, tri_sample(wood_detail, pw, w), wood);
			dn = normalize(mix(dn, tri_normal(wood_normal, pw, n, w, normal_strength), wood));
		}
		vec3 m = tri_sample(macro_noise, world_pos * macro_scale, w).rgb;
		base *= mix(1.0, 0.4 + 1.2 * d.r, detail_strength);
		base *= mix(1.0, d.b, cavity_strength * detail_strength);
		rough = mix(rough, d.g, detail_strength * 0.7);
		n = normalize(mix(n, dn, detail_strength));
		// Schmutz: helle und dunkle Flecken um die Grundhelligkeit herum (im Mittel so hell wie
		// ohne), und Wände werden zum Boden hin dunkler (Böden selbst nicht).
		float wall = 1.0 - smoothstep(0.5, 0.8, abs(world_normal.y));
		float low = (1.0 - smoothstep(0.0, grime_height, world_pos.y - ground_y)) * wall;
		float dirt = (smoothstep(0.35, 0.85, m.r) - 0.5) * grime_amount;
		base *= 1.0 - 0.45 * dirt - 0.3 * grime_amount * low;
		// Moos: auf Stein, bevorzugt in Ritzen, auf Oberseiten und unten an Wänden.
		float up = smoothstep(0.3, 0.9, n.y);
		float moss_mask = m.g + (1.0 - d.b) * 0.3 + up * 0.12 + low * 0.18;
		float moss = smoothstep(0.62, 0.8, moss_mask) * moss_amount * (1.0 - wood);
		base = mix(base, moss_color.rgb * (0.65 + 0.7 * d.r), moss);
		rough = mix(rough, 0.92, moss);
		// Nässe: Pfützen auf Böden, in den tiefen Stellen der Detail-Höhe.
		float flat_floor = smoothstep(0.85, 0.97, world_normal.y) * (1.0 - smoothstep(0.3, 0.6, world_pos.y - ground_y));
		float wet = smoothstep(0.52, 0.68, m.b + (0.5 - d.a) * 0.25) * wetness * flat_floor * (1.0 - moss);
		base *= mix(1.0, 0.62, wet);
		rough = mix(rough, 0.06, wet);
		n = normalize(mix(n, normalize(world_normal), wet * 0.9));
	}
	ALBEDO = base;
	ROUGHNESS = clamp(rough, 0.04, 1.0);
	METALLIC = metallic;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
