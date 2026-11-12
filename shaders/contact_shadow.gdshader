shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

// Sombra de contacto de un vehículo: una mancha oscura de bordes suaves pegada al suelo, bajo el
// casco y un poco alrededor. Asienta el tanque en el terreno y lo separa de él cuando los dos son
// de un color parecido o cuando el sol apenas da sombra (niebla, lluvia, nieve).
uniform float strength = 0.42;

void fragment() {
	vec2 q = abs(UV * 2.0 - 1.0);
	// Rectángulo de esquinas redondas: entero bajo el casco y desvanecido hacia el borde.
	float outside = length(max(q - vec2(0.42, 0.5), vec2(0.0)));
	float shade = 1.0 - smoothstep(0.0, 0.5, outside);
	ALBEDO = vec3(0.0);
	ALPHA = shade * shade * strength;
}
