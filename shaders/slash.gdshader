shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Rastro de golpe em arco (estilo Hades): núcleo branco e bordas coloridas, varrendo do início ao fim.
uniform vec4 color : source_color = vec4(1.0, 0.7, 0.3, 1.0);
uniform float progress = 1.0;
uniform float fade = 1.0;
uniform float trail = 0.75;

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float body = smoothstep(progress - trail, progress, u) * (1.0 - step(progress + 0.001, u));
	float across = smoothstep(0.0, 0.45, v) * (1.0 - smoothstep(0.88, 1.0, v));
	float core = smoothstep(0.55, 0.82, v) * (1.0 - smoothstep(0.82, 0.98, v));
	vec3 c = mix(color.rgb, vec3(1.0), core * 0.85);
	float a = body * across * fade;
	ALBEDO = c * 1.6;
	ALPHA = clamp(a, 0.0, 1.0);
}
