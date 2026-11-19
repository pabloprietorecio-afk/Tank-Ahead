shader_type spatial;
render_mode cull_back;

#include "res://shaders/surface_common.gdshaderinc"

// Mar del fondo: un plano fuera del campo. Oleaje a dos escalas, más claro y con rompiente
// junto a la orilla (UV.y = 0 en la playa, 1 mar adentro).
uniform vec3 deep_color : source_color = vec3(0.07, 0.19, 0.3);
uniform vec3 shore_color : source_color = vec3(0.22, 0.42, 0.44);
// Metros de mar somero junto a la playa.
uniform float shelf = 120.0;
uniform float reach = 2400.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float out_m = UV.y * reach;
	float t = TIME * 0.35;
	float swell = noise4(vec2(p.x * 0.012 + t * 0.2, p.y * 0.03 - t)).r;
	float chop = noise4(p * 0.09 + vec2(t * 0.7, -t * 0.4)).g;
	float shallow = 1.0 - smoothstep(0.0, shelf, out_m + (swell - 0.5) * 30.0);
	vec3 color = mix(deep_color, shore_color, shallow);
	color *= 0.86 + swell * 0.2 + chop * 0.1;
	// Rompientes: líneas de espuma que llegan a la playa, y borreguillos mar adentro.
	float surf = smoothstep(0.82, 0.95, sin((out_m + swell * 14.0) * 0.16 - TIME * 0.9) * 0.5 + 0.5) * (1.0 - smoothstep(0.0, shelf * 0.6, out_m));
	float caps = smoothstep(0.74, 0.8, chop * 0.6 + swell * 0.4) * 0.35 * (1.0 - smoothstep(300.0, 900.0, out_m));
	color = mix(color, vec3(0.86, 0.9, 0.9), clamp(surf * 0.8 + caps, 0.0, 1.0));
	ALBEDO = color;
	ROUGHNESS = 0.25 + surf * 0.5;
	SPECULAR = 0.4;
}
