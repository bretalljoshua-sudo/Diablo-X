// Treffer-Aufblitzen als zusätzlicher Durchgang (material_overlay): hellt die Figur kurz auf,
// am Rand stärker. Stärke je Figur über die Instanz-Uniform flash.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, depth_test_default;

instance uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.92, 0.85, 1.0);

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = flash_color.rgb * flash * (0.55 + rim * 1.2);
}
