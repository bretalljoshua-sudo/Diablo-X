// Lichtsäule über seltener Beute: nach oben ausblendend, leicht wabernd, additiv.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 beam_color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float intensity = 1.5;
uniform float height = 6.0;
uniform float pulse = 0.0;

void fragment() {
	float h = clamp(UV.y, 0.0, 1.0);
	// UV.y läuft beim Zylinder von oben (0) nach unten (1).
	float fade_up = pow(h, 2.2);
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	float core = 1.0 - edge;
	float wave = 0.85 + 0.15 * sin(TIME * 3.0 + UV.y * 12.0 + UV.x * 25.0);
	float strength = fade_up * (0.15 + core * 0.7) * wave * (1.0 + pulse);
	ALBEDO = beam_color.rgb * intensity * strength;
}
