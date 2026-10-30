shader_type spatial;
render_mode cull_back;

// Visual cartoon: sombra em faixas + textura de pincel (triplanar) + luz de borda.
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform sampler2D detail_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float detail_strength = 0.0;
uniform float detail_scale = 0.9;
uniform int bands : hint_range(2, 6) = 3;
uniform vec4 rim_color : source_color = vec4(1.0, 0.82, 0.6, 1.0);
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.72;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.35;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
// personagens: cor por vértice escurece as barras das roupas (desligado no resto, onde COLOR é cor de instância)
uniform bool use_vertex_color = false;

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 vcol;

// Normal segura: modelos antigos têm vértices com normal zerada/NaN. No PC isso dá zero, mas no navegador
// (WebGL/ANGLE) normalize() vira NaN e, com o glow, um ponto NaN pinta a tela inteira de preto/azul.
vec3 safe_n(vec3 n) {
	float l = dot(n, n);
	return (l > 1e-8 && l < 1e8) ? n * inversesqrt(l) : vec3(0.0, 1.0, 0.0);
}

void vertex() {
	NORMAL = safe_n(NORMAL);
	lpos = VERTEX;
	lnrm = NORMAL;
	vcol = use_vertex_color ? COLOR.rgb : vec3(1.0);
}

void fragment() {
	vec3 col = texture(albedo_tex, UV * uv_scale).rgb * albedo.rgb * vcol;
	if (detail_strength > 0.0) {
		vec3 w = pow(abs(safe_n(lnrm)), vec3(4.0));
		w /= (w.x + w.y + w.z + 0.0001);
		vec3 p = lpos * detail_scale;
		float d = texture(detail_tex, p.zy).r * w.x + texture(detail_tex, p.xz).r * w.y + texture(detail_tex, p.xy).r * w.z;
		col *= 1.0 + (d - 0.5) * 2.0 * detail_strength;
	}
	col = mix(col, tint.rgb, tint_amount);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float edge = 1.0 - clamp(dot(safe_n(NORMAL), safe_n(VIEW)), 0.0, 1.0);
	float rim = smoothstep(rim_threshold, rim_threshold + 0.05, edge);
	EMISSION = clamp(rim_color.rgb * rim * rim_strength + vec3(flash), vec3(0.0), vec3(4.0));
	ALBEDO = clamp(ALBEDO, vec3(0.0), vec3(4.0));
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float steps = float(bands);
	float band = min(floor(ndl * steps) / (steps - 1.0), 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band / PI;
}
