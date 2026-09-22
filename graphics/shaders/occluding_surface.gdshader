// Oberfläche für Wände, Säulen und Häuser: verhält sich wie ein einfaches PBR-Material und
// blendet sich per Dithering aus, wenn sie zwischen Kamera und Spielerfigur steht.
// Die Figur setzt Graphics über die Shader-Globals occlusion_target und occlusion_radius.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform vec3 occlusion_target;
global uniform float occlusion_radius;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_roughness_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_normal_texture = false;
uniform float normal_strength : hint_range(0.0, 4.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
// true: Texturen weltbezogen von drei Seiten projizieren (Platzhalter ohne UVs).
uniform bool triplanar = true;
uniform float triplanar_scale = 0.35;
uniform float triplanar_sharpness = 4.0;
// Dunklere Kanten unten an der Wand (Schmutz, Feuchtigkeit).
uniform float grime_height = 0.9;
uniform float grime_strength : hint_range(0.0, 1.0) = 0.35;
// Ausblenden: Höhe der Wand, ab der ausgeblendet wird (die Fußleiste bleibt stehen).
uniform float occlusion_min_height = 0.35;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 sample_tri(sampler2D tex, vec3 pos, vec3 weights) {
	vec4 x = texture(tex, pos.zy * triplanar_scale);
	vec4 y = texture(tex, pos.xz * triplanar_scale);
	vec4 z = texture(tex, pos.xy * triplanar_scale);
	return x * weights.x + y * weights.y + z * weights.z;
}

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int index = i.x + i.y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[index] + 0.5) / 16.0;
}

void fragment() {
	if (occlusion_radius > 0.0 && world_pos.y > occlusion_min_height) {
		vec3 target_view = (VIEW_MATRIX * vec4(occlusion_target, 1.0)).xyz;
		vec3 frag_view = VERTEX;
		// Nur was näher an der Kamera liegt als die Figur, und nur im Kreis um sie herum.
		if (frag_view.z > target_view.z + 0.6) {
			float d = length(frag_view.xy - target_view.xy);
			float fade = 1.0 - smoothstep(occlusion_radius * 0.55, occlusion_radius, d);
			if (fade * 0.85 > bayer4(FRAGCOORD.xy)) {
				discard;
			}
		}
	}
	vec3 weights = pow(abs(world_normal), vec3(triplanar_sharpness));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	vec4 albedo_tex = triplanar ? sample_tri(albedo_texture, world_pos, weights) : texture(albedo_texture, UV);
	float rough_tex = triplanar ? sample_tri(roughness_texture, world_pos, weights).r : texture(roughness_texture, UV).r;
	float grime = 1.0 - grime_strength * (1.0 - smoothstep(0.0, grime_height, world_pos.y));
	ALBEDO = albedo_color.rgb * albedo_tex.rgb * grime;
	ROUGHNESS = clamp(roughness * rough_tex, 0.0, 1.0);
	METALLIC = metallic;
	if (use_normal_texture) {
		NORMAL_MAP = triplanar ? sample_tri(normal_texture, world_pos, weights).rgb : texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
}
