shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

// Contorno oscuro y muy fino alrededor de un vehículo: como el borde de ayuda (outline.gdshader),
// pero de un píxel y sin brillar en la niebla (se desvanece con el tanque). Recorta la silueta
// contra un terreno de color parecido, sobre todo de lejos.
uniform vec3 color : source_color = vec3(0.05, 0.045, 0.035);
uniform float min_pixels = 1.0;

void vertex() {
	if (IN_SHADOW_PASS) {
		// No da sombra: en la pasada de sombras se reduce a un punto (ver outline.gdshader).
		VERTEX = vec3(0.0);
	} else {
		vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		float pixel = max(-view.z, 0.0) * 2.0 / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
		float scale = length(MODEL_MATRIX[0].xyz);
		VERTEX += NORMAL * pixel * min_pixels / max(scale, 0.001);
	}
}

void fragment() {
	ALBEDO = color;
}
