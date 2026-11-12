shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled;

// Borde que destaca un objeto (tanques enemigos en amarillo, objetivos en azul): el mismo modelo,
// un poco más gordo y dibujado solo por sus caras traseras, asoma alrededor de la silueta.
// El grosor es `width` metros de cerca y nunca menos de `min_pixels` píxeles de pantalla, para
// que el borde no se pierda cuando el objeto está lejos.
uniform vec3 color : source_color = vec3(1.0, 0.9, 0.1);
uniform float width = 0.03;
uniform float min_pixels = 1.5;

void vertex() {
	if (IN_SHADOW_PASS) {
		// El borde es una ayuda de pantalla y no da sombra: en la pasada de sombras se reduce a
		// un punto. (Ahí la proyección es la de la luz y el grosor «en píxeles» salía de metros:
		// el modelo hinchado echaba sombras enormes por todo el campo.)
		VERTEX = vec3(0.0);
	} else {
		vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		// Metros que ocupa un píxel a la distancia de este vértice.
		float pixel = max(-view.z, 0.0) * 2.0 / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
		// Las mallas van a escala 1 o muy cerca: el grosor se da en metros del mundo.
		float scale = length(MODEL_MATRIX[0].xyz);
		VERTEX += NORMAL * max(width, pixel * min_pixels) / max(scale, 0.001);
	}
}

void fragment() {
	ALBEDO = color;
}
