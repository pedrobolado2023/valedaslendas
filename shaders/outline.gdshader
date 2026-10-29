shader_type spatial;
render_mode cull_front, unshaded;

// Contorno por "casco invertido": o modelo é inflado ao longo das normais
// e só as faces de trás aparecem, formando a linha escura ao redor.
uniform vec4 outline_color : source_color = vec4(0.04, 0.03, 0.03, 1.0);
uniform float outline_width : hint_range(0.0, 0.2) = 0.03;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
