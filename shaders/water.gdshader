shader_type spatial;
render_mode cull_back;

#include "res://shaders/surface_common.gdshaderinc"

// Agua de río o arroyo: una cinta a ras de suelo. UV.x va de 0 a 1 de orilla a orilla y UV.y
// son metros a lo largo (la corriente baja por ahí). Más clara y con espuma en las orillas y
// en los vados; oscura en el centro. Con `frozen` es hielo con nieve encima.
uniform vec3 deep_color : source_color = vec3(0.09, 0.15, 0.15);
uniform vec3 shallow_color : source_color = vec3(0.24, 0.3, 0.24);
uniform float width = 14.0;
uniform float flow = 1.2;
// Qué parte de la anchura es fondo somero (1 = todo vadeable).
uniform float shallows = 0.25;
uniform float frozen = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float near = detail_fade(VERTEX, 30.0, 140.0);
	float across = abs(UV.x - 0.5) * 2.0;
	vec2 along = vec2(UV.x * width, UV.y);
	// Ondas que bajan con la corriente, a dos escalas.
	float t = TIME * flow;
	float w1 = noise4(vec2(along.x * 0.5, along.y * 0.16 - t * 0.22)).r;
	float w2 = noise4(vec2(along.x * 1.3 + 4.0, along.y * 0.5 - t * 0.5)).g;
	float w3 = noise4(p * 1.9 + vec2(t * 0.15, -t * 0.1)).b;
	float waves = w1 * 0.5 + w2 * 0.3 + w3 * 0.2;
	float shore = smoothstep(1.0 - shallows, 1.0, across + (w1 - 0.5) * 0.15);
	vec3 color = mix(deep_color, shallow_color, shore);
	color *= 0.85 + waves * 0.3;
	// Espuma fina pegada a la orilla y rizos claros en la corriente.
	float foam = smoothstep(0.9, 1.0, across + (w2 - 0.5) * 0.12) * 0.5;
	float ripple = smoothstep(0.62, 0.7, w2 * 0.6 + w3 * 0.4) * (0.25 + shore * 0.5) * near;
	color = mix(color, vec3(0.72, 0.78, 0.76), clamp(foam + ripple * 0.35, 0.0, 1.0));
	float rough = 0.22 + shore * 0.15 + foam * 0.5;
	float h = waves * 0.05;
	if (frozen > 0.0) {
		float snow = smoothstep(0.4, 0.65, noise4(p * 0.3).r);
		vec3 ice = mix(vec3(0.55, 0.65, 0.7), vec3(0.88, 0.91, 0.94), snow);
		color = mix(color, ice * (0.9 + w3 * 0.1), frozen);
		rough = mix(rough, mix(0.2, 0.7, snow), frozen);
		h *= 1.0 - frozen;
	}
	ALBEDO = color;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.35;
	NORMAL = bump_normal(NORMAL, VERTEX, h * near);
}
