shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Pasillo de una pasada de ametrallamiento marcado en el suelo: un cerco de trazos, un velo
// tenue y flechas que corren en el sentido en que viene el caza. Lo ya barrido por las balas
// se apaga. UV.x cruza el pasillo; UV.y lo recorre de donde entra el avión a donde sale.

uniform vec3 color : source_color = vec3(1.0, 0.1, 0.05);
// Ancho y largo del pasillo (m).
uniform vec2 lane = vec2(12.0, 170.0);
// Cuenta atrás (0 acaba de marcarse, 1 llegan las balas) y parpadeo de aviso (0..1).
uniform float progress = 0.0;
uniform float alert = 1.0;
// Parte del pasillo que las balas ya han barrido (0..1 a lo largo).
uniform float swept = 0.0;

void fragment() {
	float across = abs(UV.x - 0.5) * lane.x;
	float v = UV.y * lane.y;
	float edge_x = lane.x * 0.5 - across;
	float edge_y = min(v, lane.y - v);
	// Cerco de trazos por los cuatro lados.
	float dashes_long = step(0.4, fract(v / 5.0 - TIME * 0.6));
	float dashes_short = step(0.4, fract(across / 2.0));
	float rim = (1.0 - smoothstep(0.22, 0.38, edge_x)) * dashes_long;
	rim = max(rim, (1.0 - smoothstep(0.22, 0.38, edge_y)) * dashes_short);
	// Flechas: la punta, en el centro y por delante; corren más deprisa según se acaba el tiempo.
	float arrows = step(fract((v + across * 1.15) / 11.0 - TIME * (0.9 + progress * 1.6)), 0.16);
	arrows *= step(0.5, edge_x);
	float veil = 0.08 + 0.12 * alert + 0.08 * progress;
	float alive = step(swept, UV.y);
	ALBEDO = color;
	ALPHA = clamp(max(max(rim * 0.9, arrows * 0.55), veil), 0.0, 1.0) * alive;
}
