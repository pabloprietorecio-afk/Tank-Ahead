shader_type spatial;
render_mode cull_back;

#include "res://shaders/surface_common.gdshaderinc"
#include "res://shaders/far_common.gdshaderinc"

// Relieve lejano, fuera del campo: colinas con sus parcelas, mesetas y escarpes del desierto,
// ondulaciones de la estepa, montes de roca. Lo llano lleva las parcelas del frente y lo
// escarpado enseña la roca en estratos.
// kind: 0 según el frente (parcelas + roca en lo escarpado), 1 monte de roca pelada con matas
// al pie, 2 colina de bosque cerrado.
uniform int kind = 0;
uniform vec3 rock_color : source_color = vec3(0.45, 0.4, 0.33);
// Altura (m) a la que la roca clarea: los estratos de arriba, más pálidos.
uniform float crest = 40.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = world_pos.xz;
	vec4 nz = noise4(p * 0.02 + 5.0);
	float steep = smoothstep(0.1, 0.32, 1.0 - world_normal.y + (nz.r - 0.5) * 0.08);
	// Roca en estratos horizontales, con cárcavas que bajan.
	float bed = fract(world_pos.y * 0.16 + nz.g * 0.5);
	float strata = smoothstep(0.0, 0.12, bed) * (1.0 - smoothstep(0.55, 0.7, bed));
	float gully = noise4(vec2(p.x * 0.06 + p.y * 0.04, world_pos.y * 0.01)).b;
	vec3 rock = rock_color * (0.72 + strata * 0.3 + (gully - 0.5) * 0.3);
	rock = mix(rock, rock * 1.2, smoothstep(crest * 0.4, crest, world_pos.y));
	vec3 land = far_fields(p);
	vec3 color;
	if (kind == 1) {
		// Monte pelado: roca casi entera; al pie, derrubios y matas.
		float foot = 1.0 - smoothstep(crest * 0.08, crest * 0.4, world_pos.y + nz.a * crest * 0.2);
		color = mix(rock, land * 0.9, foot * (1.0 - steep * 0.6));
	} else if (kind == 2) {
		// Bosque: copas apretadas, más oscuras en las vaguadas.
		float crowns = noise4(p * 0.11).r * 0.6 + noise4(p * 0.31 + 9.0).g * 0.4;
		color = field_line * (0.75 + crowns * 0.7) * (0.85 + nz.b * 0.3);
		color = mix(color, land, smoothstep(0.72, 0.8, noise4(p * 0.006 + 80.0).a) * 0.8);
	} else {
		color = mix(land, rock, steep);
	}
	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
