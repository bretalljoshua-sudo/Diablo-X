// Auflösen beim Tod: Pixel verschwinden nach einem Rauschmuster, an der Kante glüht es wie Glut.
// progress läuft von 0 (ganz da) bis 1 (weg). Vfx setzt die Werte je Figur.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform sampler2D noise_texture : hint_default_white, repeat_enable;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width = 0.08;
uniform vec4 edge_color : source_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform float edge_energy = 6.0;
uniform float noise_scale = 0.9;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// Rauschen im Objektraum, damit das Muster an der Figur klebt; leichter Verlauf von oben.
	float n = texture(noise_texture, local_pos.xy * noise_scale + local_pos.z * 0.37).r;
	n = mix(n, 1.0 - clamp(local_pos.y * 0.35, 0.0, 1.0), 0.25);
	float cut = progress * (1.0 + edge_width);
	if (n < cut - edge_width) {
		discard;
	}
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = albedo_color.rgb * tex.rgb;
	ROUGHNESS = roughness;
	float edge = 1.0 - smoothstep(0.0, edge_width, n - (cut - edge_width));
	EMISSION = edge_color.rgb * edge * edge_energy * step(0.001, progress);
}
