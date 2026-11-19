shader_type spatial;
render_mode cull_back;

#include "res://shaders/surface_common.gdshaderinc"

// Cinta pegada al suelo: caminos, calles, orillas, lechos secos, balasto de vía y fondos de
// trinchera. UV.x va de 0 a 1 de orilla a orilla y UV.y son metros a lo largo.
// pattern: 0 camino de tierra con rodadas, 1 adoquines, 2 barro de orilla, 3 balasto,
//          4 tierra removida (trinchera), 5 lecho seco de rambla, 6 tablones (puente).
uniform vec3 base_color : source_color = vec3(0.34, 0.27, 0.18);
uniform vec3 detail_color : source_color = vec3(0.22, 0.17, 0.11);
uniform int pattern = 0;
uniform float width = 8.0;
// Borde irregular (0 = recto, 1 = muy comido).
uniform float ragged = 0.6;
// Suelo mojado (0..1) y nieve (0..1), como el terreno.
uniform float wet = 0.0;
uniform float tint = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float near = detail_fade(VERTEX, 25.0, 90.0);
	float across = abs(UV.x - 0.5) * 2.0;
	vec4 mid = noise4(p * 0.45 + 3.0);
	vec4 fine = noise4(p * 2.4 + 11.0);
	// Orilla comida por la hierba.
	float edge = across + (mid.r - 0.5) * ragged * 0.5 + (fine.g - 0.5) * ragged * 0.2;
	if (edge > 1.0) {
		discard;
	}
	vec3 color = base_color * (0.78 + mid.g * 0.3 + (fine.r - 0.5) * 0.2 * near);
	float h = fine.r * 0.02;
	float rough = 0.95;
	if (pattern == 0) {
		// Dos rodadas a lo largo y piedrecillas.
		float lane = abs(abs(UV.x - 0.5) * width - 1.5);
		float rut = 1.0 - smoothstep(0.3, 0.7, lane);
		color = mix(color, detail_color, rut * 0.6);
		float pebble = smoothstep(0.82, 0.93, noise4(p * 17.0).b) * near;
		color = mix(color, color * 1.4, pebble * 0.4);
		h -= rut * 0.05;
	} else if (pattern == 1) {
		// Adoquines en hiladas trabadas.
		vec2 q = vec2(UV.x * width, UV.y) * 2.6;
		float row = floor(q.y);
		q.x += mod(row, 2.0) * 0.5;
		vec2 f = fract(q);
		float joint = max(1.0 - smoothstep(0.0, 0.1, min(f.x, 1.0 - f.x)), 1.0 - smoothstep(0.0, 0.1, min(f.y, 1.0 - f.y))) * near;
		float id = hash(floor(q));
		color = base_color * (0.7 + id * 0.4 + (fine.r - 0.5) * 0.15);
		color = mix(color, detail_color, joint * 0.8);
		h = (1.0 - joint) * 0.03;
		rough = 0.8;
	} else if (pattern == 2) {
		// Barro: más oscuro y húmedo hacia el agua.
		float damp = 1.0 - smoothstep(0.35, 0.95, across);
		color = mix(color, detail_color, damp * 0.7);
		rough = mix(0.9, 0.45, damp);
	} else if (pattern == 3) {
		// Balasto: piedra machacada.
		float stone = noise4(p * 9.0).r * 0.6 + noise4(p * 23.0 + 4.0).g * 0.4 * near;
		color = base_color * (0.6 + stone * 0.7);
		h = stone * 0.04;
	} else if (pattern == 4) {
		// Tierra removida: terrones oscuros.
		float clod = noise4(p * 5.0).r;
		color = mix(detail_color, base_color, smoothstep(0.3, 0.7, clod)) * (0.8 + fine.b * 0.3);
		h = clod * 0.05;
	} else if (pattern == 5) {
		// Lecho seco: arena lavada, grava y cantos rodados.
		float gravel_f = smoothstep(0.5, 0.75, noise4(p * 0.8 + 7.0).g);
		float cobble = smoothstep(0.7, 0.85, noise4(p * 6.0).b) * near;
		color = mix(color, detail_color * 1.6, gravel_f * 0.5);
		color = mix(color, base_color * vec3(0.8, 0.8, 0.82) * (0.75 + fine.a * 0.4), cobble * 0.55);
		h = cobble * 0.04;
	} else if (pattern == 6) {
		// Tablones atravesados.
		float boards = groove(UV.y * 2.2, 0.035);
		float id = hash(vec2(floor(UV.y * 2.2), 3.0));
		float grain = noise4(vec2(UV.x * width * 0.6, UV.y * 30.0)).r;
		color = base_color * (0.7 + id * 0.35 + grain * 0.2);
		color = mix(color, detail_color, boards * 0.85);
		h = -boards * 0.03;
		rough = 0.85;
	}
	if (wet > 0.0) {
		color *= 1.0 - wet * 0.25;
		rough = mix(rough, 0.45, wet * 0.7);
	}
	if (tint > 0.0) {
		float snow = tint * smoothstep(0.35, 0.7, mid.b + across * 0.4) * (pattern == 1 || pattern == 6 ? 0.55 : 0.8);
		color = mix(color, vec3(0.86, 0.89, 0.93), snow);
	}
	ALBEDO = color;
	ROUGHNESS = rough;
	NORMAL = bump_normal(NORMAL, VERTEX, h * near);
}
