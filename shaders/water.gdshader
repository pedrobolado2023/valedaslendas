shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Lago: água estilizada com ondas, brilho do céu (reflexo) e espuma na margem.
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec3 deep : source_color = vec3(0.02, 0.07, 0.13);
uniform vec3 shallow : source_color = vec3(0.05, 0.2, 0.27);
uniform vec3 sky : source_color = vec3(0.95, 0.62, 0.5);
uniform vec3 foam : source_color = vec3(0.6, 0.78, 0.8);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	if (r > 1.0) {
		discard;
	}
	vec2 w = wpos.xz;
	float n1 = texture(noise_tex, w * 0.05 + vec2(TIME * 0.01, TIME * 0.006)).r;
	float n2 = texture(noise_tex, w * 0.09 - vec2(TIME * 0.008, -TIME * 0.012)).r;
	float waves = n1 * 0.6 + n2 * 0.4;
	vec3 col = mix(shallow, deep, smoothstep(0.1, 0.8, 1.0 - r));
	// faixas de reflexo do céu
	float glint = smoothstep(0.66, 0.69, waves) * (1.0 - smoothstep(0.69, 0.72, waves));
	col = mix(col, sky, glint * 0.3);
	float sparkle = step(0.86, fract(sin(dot(floor(w * 3.0), vec2(12.9898, 78.233))) * 43758.5453)) * step(0.7, n2) * (0.5 + 0.5 * sin(TIME * 4.0 + w.x));
	col += sky * sparkle * 0.25;
	// espuma na margem
	float edge = smoothstep(0.93, 0.975, r + (n1 - 0.5) * 0.04);
	col = mix(col, foam, edge * 0.55);
	ALBEDO = col;
}
