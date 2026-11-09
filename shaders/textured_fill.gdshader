shader_type spatial;
render_mode cull_back;

#include "res://shaders/surface_common.gdshaderinc"

// Superficie iluminada con textura procedural para mallas no cúbicas.
// pattern: 0 liso, 1 corteza, 2 follaje, 3 roca, 4 metal con aros, 5 tejas, 6 madera.
uniform vec3 base_color : source_color = vec3(0.5);
uniform vec3 detail_color : source_color = vec3(0.2);
uniform int pattern = 0;
uniform float scale = 1.0;
// Camuflaje: 0 liso, 1 manchas, 2 franjas, 3 encalado de invierno.
uniform int camo_mode = 0;
uniform vec3 camo_a : source_color = vec3(0.3, 0.35, 0.2);
uniform vec3 camo_b : source_color = vec3(0.35, 0.25, 0.15);
uniform float camo_scale = 1.0;
uniform float roughness_value = 0.9;
uniform float metallic_value = 0.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 p = lp / scale;
	float around = atan(p.z, p.x);
	float d = 0.0;
	float shade = 0.85 + fbm(p.xz * 2.0 + p.y) * 0.3;
	if (pattern == 1) {
		d = line(around * 2.5 + noise(vec2(p.y * 3.0, 0.0)) * 0.8, 2.0) * 0.8;
	} else if (pattern == 2) {
		float n = fbm(vec2(around * 3.0, p.y * 7.0) + p.xz * 3.0);
		d = smoothstep(0.45, 0.75, n);
		shade *= 0.8 + (p.y + 0.5) * 0.4;
	} else if (pattern == 3) {
		float strata = line(p.y * 1.5 + fbm(p.xz * 0.8) * 1.5, 1.5);
		float cracks = line(around * 3.0 + fbm(vec2(p.y, around)) * 2.0, 1.0) * step(0.55, noise(p.xz * 1.5 + p.y));
		d = max(strata * 0.6, cracks * 0.7) + fbm(p.xz * 6.0 + p.y * 3.0) * 0.3;
	} else if (pattern == 4) {
		d = max(line(p.y * 2.5, 1.5), step(0.93, sin(around * 6.0)) * 0.5);
	} else if (pattern == 5) {
		float row = floor(p.y * 4.0);
		d = max(line(p.y * 4.0, 1.5), line(p.x * 2.5 + mod(row, 2.0) * 0.5, 1.0) * 0.7);
	} else if (pattern == 6) {
		d = line(p.x * 1.5 + noise(p.yz * 4.0) * 0.4, 1.0) * 0.7;
	}
	vec3 painted = apply_camo(base_color, camo_mode, camo_a, camo_b, camo_scale, lp);
	ALBEDO = mix(painted * shade, detail_color, clamp(d, 0.0, 1.0));
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
}
