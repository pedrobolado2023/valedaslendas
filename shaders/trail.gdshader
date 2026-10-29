shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Setas da trilha até a missão, com um pulso que corre na direção do objetivo.
uniform vec4 color : source_color = vec4(1.0, 0.82, 0.35, 1.0);
varying float idx;

void vertex() {
	idx = INSTANCE_CUSTOM.x;
}

void fragment() {
	float pulse = pow(0.5 + 0.5 * sin(TIME * 5.0 - idx * 0.7), 3.0);
	ALBEDO = color.rgb * (0.6 + 1.2 * pulse);
	ALPHA = 0.35 + 0.65 * pulse;
}
