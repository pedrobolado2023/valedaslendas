shader_type spatial;
render_mode cull_front, unshaded;

// Contorno por "casco invertido": o modelo é inflado ao longo das normais
// e só as faces de trás aparecem, formando a linha escura ao redor.
uniform vec4 outline_color : source_color = vec4(0.04, 0.03, 0.03, 1.0);
uniform float outline_width : hint_range(0.0, 0.2) = 0.03;


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

void vertex() {
	// normal zerada/NaN (modelos antigos): sem inflar, senão o vértice vira NaN no navegador
	float l = dot(NORMAL, NORMAL);
	vec3 n = (l > 1e-8 && l < 1e8) ? NORMAL * inversesqrt(l) : vec3(0.0);
	VERTEX += n * outline_width + wind_offset(VERTEX, MODEL_MATRIX, TIME);
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
