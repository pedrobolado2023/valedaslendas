shader_type spatial;

// Chão pintado: grama, terra da trilha e pedra misturadas por uma máscara (R=trilha, G=floresta, B=pedra).
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mask_tex : filter_linear;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform float world_size = 300.0;
uniform float tile = 0.11;
uniform vec3 grass_tint : source_color = vec3(0.46, 0.6, 0.54);
uniform vec3 forest_tint : source_color = vec3(0.42, 0.55, 0.66);
uniform vec3 dirt_tint : source_color = vec3(0.74, 0.6, 0.52);
uniform vec3 stone_tint : source_color = vec3(0.55, 0.56, 0.64);
uniform float lava_amount = 0.0;
uniform float path_scale = 1.2;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = wpos.xz;
	vec2 muv = w / world_size + 0.5;
	vec4 m = texture(mask_tex, muv);
	float n = texture(noise_tex, w * 0.012).r;
	float n2 = texture(noise_tex, w * 0.06 + vec2(0.37, 0.71)).r;
	vec3 g = texture(grass_tex, w * tile).rgb;
	vec3 g2 = texture(grass_tex, w * tile * 0.31 + vec2(0.5)).rgb;
	g = mix(g, g2, 0.4) * grass_tint * mix(0.78, 1.12, n);
	g = mix(g, g * forest_tint * 1.4, smoothstep(0.1, 0.9, m.g));
	vec3 d = texture(dirt_tex, w * tile * path_scale).rgb * dirt_tint * mix(0.85, 1.08, n2);
	vec3 s = texture(stone_tex, w * 0.18).rgb * stone_tint * mix(0.8, 1.1, n);
	float road = smoothstep(0.32, 0.62, m.r + (n2 - 0.5) * 0.45);
	float stone = smoothstep(0.3, 0.6, m.b + (n2 - 0.5) * 0.4);
	vec3 col = mix(g, d, road);
	col = mix(col, s, stone);
	// borda escura da trilha (contorno pintado)
	float rim = smoothstep(0.18, 0.32, m.r + (n2 - 0.5) * 0.45) * (1.0 - road);
	col *= 1.0 - rim * 0.35;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (lava_amount > 0.0) {
		// rachaduras de lava brilhando no chão do vulcão
		float n3 = texture(noise_tex, w * 0.035 + vec2(0.13, 0.57)).r;
		float crack = 1.0 - smoothstep(0.0, 0.018, abs(n3 - 0.5));
		float pulse = 0.75 + 0.25 * sin(TIME * 1.5 + w.x * 0.1);
		EMISSION = vec3(1.0, 0.32, 0.05) * crack * lava_amount * (1.0 - road) * (1.0 - stone) * pulse * 2.0;
	}
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float band = min(floor(ndl * 3.0) / 2.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band / PI;
}
