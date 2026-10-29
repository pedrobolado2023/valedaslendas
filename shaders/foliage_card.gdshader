shader_type spatial;
render_mode cull_disabled;

// Tufos de grama e flores (planos cruzados) balançando com o vento.
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float tint_whites = 0.0;
uniform float sway = 0.12;

varying float phase;
varying vec4 icol;

void vertex() {
	phase = INSTANCE_CUSTOM.x;
	icol = COLOR;
	float bend = 1.0 - UV.y;
	VERTEX.x += sin(TIME * 1.7 + phase) * sway * bend;
	VERTEX.z += cos(TIME * 1.3 + phase * 1.3) * sway * 0.6 * bend;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec4 t = texture(tex, UV);
	if (t.a < 0.5) {
		discard;
	}
	vec3 c;
	if (tint_whites > 0.5) {
		float wht = smoothstep(0.7, 0.95, min(min(t.r, t.g), t.b));
		c = mix(t.rgb * vec3(0.7, 0.85, 0.75), t.rgb * icol.rgb, wht);
	} else {
		c = t.rgb * icol.rgb;
	}
	c *= mix(0.5, 1.0, 1.0 - UV.y);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float band = min(floor(ndl * 3.0) / 2.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (0.35 + 0.65 * band) / PI;
}
