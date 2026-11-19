shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_disabled;

// Huella de oruga: una tira pegada al suelo con las marcas de los eslabones. Cada tramo
// (instancia) lleva en INSTANCE_CUSTOM cuándo se dejó (x) y lo marcada que queda (y).
uniform vec3 tint : source_color = vec3(0.3, 0.24, 0.17);
uniform float now = 0.0;
uniform float life = 200.0;

varying float mark;
varying float reach;

void vertex() {
	float age = now - INSTANCE_CUSTOM.x;
	mark = INSTANCE_CUSTOM.y * (1.0 - smoothstep(life * 0.55, life, age));
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	reach = length(view.xyz);
	// La huella va pegada al suelo: se acerca un pelo a la cámara a lo largo de su mismo rayo
	// (queda donde estaba en pantalla) para que el suelo no se la coma a trozos de lejos.
	POSITION = PROJECTION_MATRIX * vec4(view.xyz * 0.994, 1.0);
}

void fragment() {
	// Bordes blandos y, a lo largo, el dibujo de los eslabones.
	float edge = smoothstep(0.0, 0.16, UV.x) * smoothstep(1.0, 0.84, UV.x);
	float cleat = smoothstep(0.18, 0.5, abs(fract(UV.y * 6.0) - 0.5) * 2.0);
	// De lejos se funde con el suelo (y no parpadea contra él).
	float near = 1.0 - smoothstep(110.0, 190.0, reach);
	ALBEDO = tint * mix(0.78, 1.0, cleat);
	ROUGHNESS = 1.0;
	ALPHA = edge * mix(0.5, 0.95, cleat) * mark * near;
}
