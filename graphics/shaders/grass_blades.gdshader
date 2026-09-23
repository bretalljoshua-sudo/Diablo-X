// Grashalme für GroundClutter (AP1): Farbverlauf vom dunklen Grund zur Spitze, Wind, Licht von
// hinten durch die Halme. UV.y ist die Höhe im Halm (0 unten, 1 Spitze), COLOR der Farbton je
// Büschel aus der MultiMesh.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.06, 0.08, 0.035, 1.0);
uniform vec4 tip_color : source_color = vec4(0.34, 0.42, 0.16, 1.0);
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.3;
uniform float translucency : hint_range(0.0, 1.0) = 0.5;

varying float height;

void vertex() {
	height = UV.y;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wind_speed;
	float gust = sin(t * 0.37 + wp.x * 0.05 + wp.z * 0.04) * 0.5 + 0.5;
	float sway = sin(t + wp.x * 0.35 + wp.z * 0.27) * 0.6 + sin(t * 2.3 + wp.x * 1.1) * 0.25;
	float bend = height * height * wind_strength * (0.6 + gust);
	VERTEX.x += sway * bend;
	VERTEX.z += cos(t * 0.8 + wp.z * 0.4) * bend * 0.5;
	// Weiche, nach oben zeigende Normalen: Wiesen wirken sonst streifig.
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.7));
}

void fragment() {
	vec3 color = mix(base_color.rgb, tip_color.rgb, smoothstep(0.0, 1.0, height)) * COLOR.rgb;
	ALBEDO = color;
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
	BACKLIGHT = color * translucency;
	AO = mix(0.35, 1.0, height);
	AO_LIGHT_AFFECT = 0.4;
}
