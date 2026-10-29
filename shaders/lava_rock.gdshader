shader_type spatial;
// Rocha escura com rachaduras de lava pulsando (porte do shader do dragon_boss.html do Gemini).
// A posição de repouso vem nos UVs (UV = x,y; UV2.x = z) para as rachaduras ficarem presas ao corpo animado;
// UV2.y = força do brilho da peça. Tem flash/tint como o toon (ModelKit.flash / set_tint).
render_mode cull_disabled, diffuse_toon, specular_toon;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float crack_scale = 5.0;
uniform float glow = 1.0;
uniform float fill = 0.0;
uniform bool use_vertex_color = true;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;

varying vec3 rest;
varying float mat_glow;

vec3 h3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

vec3 vor(vec3 x) {
	vec3 p = floor(x), f = fract(x);
	float d1 = 8.0, d2 = 8.0, id = 0.0;
	for (int k = -1; k <= 1; k++) for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
		vec3 g = vec3(float(i), float(j), float(k));
		vec3 o = h3(p + g);
		vec3 r = g + o - f;
		float d = dot(r, r);
		if (d < d1) { d2 = d1; d1 = d; id = o.x; } else if (d < d2) { d2 = d; }
	}
	return vec3(sqrt(d1), sqrt(d2), id);
}

void vertex() {
	rest = vec3(UV.x, 1.0 - UV.y, UV2.x);   // o glTF inverte o V
	mat_glow = 1.0 - UV2.y;
}

void fragment() {
	vec3 v = vor(rest * crack_scale);
	float edge = v.y - v.x;
	float plate = smoothstep(0.0, 0.38, edge);
	float crack = 1.0 - smoothstep(0.0, 0.05, edge);
	vec3 base = albedo.rgb * (use_vertex_color ? COLOR.rgb : vec3(1.0));
	base *= (0.6 + 0.8 * v.z) * (0.5 + 0.5 * plate) * 1.8;
	base = mix(base, tint.rgb, tint_amount);
	ALBEDO = mix(base, vec3(1.0), flash);
	ROUGHNESS = 0.75;
	float pulse = 0.75 + 0.25 * sin(TIME * 1.7 + v.z * 12.0);
	vec3 hot = mix(vec3(1.0, 0.2, 0.02), vec3(1.0, 0.6, 0.12), smoothstep(0.02, 0.0, edge));
	EMISSION = (hot * crack * pulse * 1.3 + vec3(1.0, 0.3, 0.05) * fill * (0.4 + 0.6 * v.z) * pulse) * glow * mat_glow;
}
