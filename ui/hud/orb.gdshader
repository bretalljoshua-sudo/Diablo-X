shader_type canvas_item;
// Flüssigkeitskugel für Leben und Wut: Füllstand mit Wellen, heller Nachlauf beim Verlust,
// Kugelschattierung und Glanzlicht.

uniform vec4 liquid_color : source_color = vec4(0.75, 0.06, 0.05, 1.0);
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float trail : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float alpha = 1.0 - smoothstep(0.96, 1.0, r);
	float active = step(0.001, fill) * step(fill, 0.999);
	float wave = (sin(p.x * 6.0 + TIME * 2.0) * 0.025 + sin(p.x * 11.0 - TIME * 3.1) * 0.012) * active;
	float surface = 1.0 - 2.0 * fill + wave;
	float trail_surface = 1.0 - 2.0 * trail;
	vec3 color = vec3(0.025, 0.02, 0.02);
	if (p.y > trail_surface) {
		color = mix(color, liquid_color.rgb * 0.6 + vec3(0.2), 0.35);
	}
	if (p.y > surface) {
		float depth = clamp(p.y - surface, 0.0, 2.0);
		color = liquid_color.rgb * (1.15 - 0.45 * depth);
		float swirl = sin(p.x * 4.0 + p.y * 3.0 + TIME * 0.7) * 0.5 + 0.5;
		swirl *= sin(p.x * 7.0 - p.y * 5.0 - TIME * 0.4) * 0.5 + 0.5;
		color += liquid_color.rgb * swirl * 0.25;
		color += vec3(0.45) * (1.0 - smoothstep(0.0, 0.045, abs(p.y - surface))) * active;
	}
	color *= mix(1.0, 0.3, smoothstep(0.35, 1.0, r));
	float highlight = 1.0 - smoothstep(0.0, 0.38, length(p - vec2(-0.32, -0.45)));
	color += vec3(highlight * 0.3);
	COLOR = vec4(color, alpha);
}
