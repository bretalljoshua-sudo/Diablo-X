// Letzter Bildschliff (AP1) über der 3D-Welt und unter der Oberfläche: leichtes Nachschärfen,
// Vignette und feines Filmkorn. Liegt auf einer CanvasLayer mit negativer Ebene (siehe
// Graphics.make_post_layer()), die Oberfläche aus AP7 bleibt also unberührt.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float sharpen : hint_range(0.0, 1.0) = 0.25;
uniform float vignette : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_softness : hint_range(0.1, 1.0) = 0.6;
uniform float grain : hint_range(0.0, 0.2) = 0.03;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 color = texture(screen_texture, uv).rgb;
	if (sharpen > 0.0) {
		vec3 blur = texture(screen_texture, uv + vec2(px.x, 0.0)).rgb
			+ texture(screen_texture, uv - vec2(px.x, 0.0)).rgb
			+ texture(screen_texture, uv + vec2(0.0, px.y)).rgb
			+ texture(screen_texture, uv - vec2(0.0, px.y)).rgb;
		color = max(color + (color - blur * 0.25) * sharpen, vec3(0.0));
	}
	// Vignette: Ecken sanft dunkler, Seitenverhältnis berücksichtigt.
	vec2 centered = (uv - 0.5) * vec2(px.y / px.x, 1.0);
	float dist = length(centered) / length(vec2(0.5 * px.y / px.x, 0.5));
	color *= mix(1.0, smoothstep(1.0, 1.0 - vignette_softness, dist), vignette);
	// Filmkorn, in dunklen Bereichen stärker (wie echtes Korn).
	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	float noise = hash(FRAGCOORD.xy + fract(TIME * 7.13) * 431.0) - 0.5;
	color += noise * grain * (1.0 - smoothstep(0.0, 0.6, lum) * 0.6);
	COLOR = vec4(color, 1.0);
}
