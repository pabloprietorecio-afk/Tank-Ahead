shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Pasillo de una pasada de ametrallamiento marcado en el suelo, sin relleno: dos rayas de trazos
// en los bordes (los trazos corren en el sentido en que viene el caza) y, por dentro, dos rayas
// que se cierran de fuera hacia el centro como cuenta atrás, igual que el anillo del bombardeo.
// En cada punto se juntan justo cuando llegan allí las balas, así que dibujan una cuña que
// apunta hacia donde va el avión. Lo ya barrido se apaga.
// UV.x cruza el pasillo; UV.y lo recorre de donde entra el avión a donde sale.

uniform vec3 color : source_color = vec3(1.0, 0.1, 0.05);
// Ancho y largo del pasillo (m).
uniform vec2 lane = vec2(12.0, 170.0);
// Segundos desde el aviso, los que tardan las balas en llegar al pasillo y su velocidad (m/s).
uniform float elapsed = 0.0;
uniform float warning = 5.0;
uniform float speed = 85.0;
// Parte del pasillo que las balas ya han barrido (0..1 a lo largo).
uniform float swept = 0.0;

float stripe(float distance_m, float half_width, float soft) {
	return 1.0 - smoothstep(half_width, half_width + soft, abs(distance_m));
}

void fragment() {
	float half_lane = lane.x * 0.5;
	float across = abs(UV.x - 0.5) * lane.x;
	float v = UV.y * lane.y;
	float soft = max(fwidth(across), 0.02) * 1.5;
	// Bordes: trazos que corren hacia donde va el caza.
	float dashes = step(0.45, fract(v / 4.0 - TIME * 1.1));
	float rim = stripe(across - (half_lane - 0.2), 0.13, soft) * dashes;
	// Rayas que se cierran: llegan al centro cuando las balas llegan a este punto.
	float due = clamp(elapsed / (warning + v / speed), 0.0, 1.0);
	float closing = stripe(across - (half_lane - 0.2) * (1.0 - due), 0.16, soft);
	float alive = step(swept, UV.y);
	ALBEDO = color;
	ALPHA = clamp(max(rim * 0.9, closing * 0.85), 0.0, 1.0) * alive;
}
