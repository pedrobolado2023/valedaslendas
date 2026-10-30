shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

// Cabelo/sobrancelha (cartões de mechas do MakeHuman): igual ao toon.gdshader, mas sem esconder o verso e com
// recorte de transparência (ALPHA_SCISSOR). Usado pelo ModelKit quando o material vem com alpha MASK do glTF.
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


// Vento (árvores e arbustos): balança mais no alto do modelo; fase pela posição no mundo. 0 = parado.
uniform float wind = 0.0;
vec3 wind_offset(vec3 v, mat4 model, float t) {
	if (wind <= 0.0) {
		return vec3(0.0);
	}
	vec3 wp = (model * vec4(v, 1.0)).xyz;
	float h = max(v.y, 0.0);
	float bend = h * h * wind;
	float ph = wp.x * 0.35 + wp.z * 0.27;
	return vec3(sin(t * 1.6 + ph) * bend, 0.0, cos(t * 1.2 + ph * 1.3) * bend * 0.6);
}

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
	VERTEX += wind_offset(VERTEX, MODEL_MATRIX, TIME);
	lnrm = NORMAL;
	vcol = use_vertex_color ? COLOR.rgb : vec3(1.0);
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;   // verso do cartão de mechas: iluminado como a frente
	}
	vec4 tx = texture(albedo_tex, UV * uv_scale);
	vec3 col = tx.rgb * albedo.rgb * vcol;
	ALPHA = tx.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
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
