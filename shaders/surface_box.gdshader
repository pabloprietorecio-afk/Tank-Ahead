shader_type spatial;
render_mode cull_back;

#include "res://shaders/surface_common.gdshaderinc"

// Caja iluminada con textura procedural y aristas biseladas.
// pattern: 0 hormigón, 1 fachada con ventanas, 2 ladrillo, 3 orugas, 4 placas blindadas,
//          5 tablones, 6 chapa ondulada / rejilla.
uniform vec3 half_size = vec3(1.0);
uniform vec3 base_color : source_color = vec3(0.5);
uniform int pattern = 0;
uniform float pattern_scale = 2.0;
// Camuflaje: 0 liso, 1 manchas, 2 franjas, 3 encalado de invierno.
uniform int camo_mode = 0;
uniform vec3 camo_a : source_color = vec3(0.3, 0.35, 0.2);
uniform vec3 camo_b : source_color = vec3(0.35, 0.25, 0.15);
uniform float camo_scale = 1.0;
uniform float roughness_value = 0.85;
uniform float metallic_value = 0.0;
uniform float edge_light = 0.12;

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec3 d = half_size - abs(local_pos);
	float smallest = min(d.x, min(d.y, d.z));
	float largest = max(d.x, max(d.y, d.z));
	float second = d.x + d.y + d.z - smallest - largest;
	float edge = 1.0 - clamp(second / (fwidth(second) * 2.0 + 0.00001), 0.0, 1.0);

	vec3 n = abs(local_normal);
	bool top_face = n.y > 0.5;
	bool side_face = n.x > 0.5;
	vec2 uv = top_face ? local_pos.xz : (side_face ? local_pos.zy : local_pos.xy);
	float along = uv.x;

	float grime = fbm(uv * 1.7 / pattern_scale + local_pos.yx * 0.3);
	float detail = 0.0;
	vec3 tint = vec3(1.0);
	vec3 emission = vec3(0.0);
	float rough = roughness_value;

	if (pattern == 1 && !top_face) {
		vec2 cell = vec2(along / (pattern_scale * 0.9), local_pos.y / pattern_scale);
		vec2 f = fract(cell);
		float glass = step(0.25, f.x) * step(f.x, 0.75) * step(0.3, f.y) * step(f.y, 0.75);
		float lit = step(0.7, hash(floor(cell) + floor(half_size.xz)));
		tint = mix(vec3(1.0), vec3(0.15, 0.18, 0.22), glass);
		emission = glass * lit * vec3(1.0, 0.8, 0.45) * 0.9;
		rough = mix(rough, 0.2, glass);
		detail = line(cell.y, 1.0) * 0.6;
	} else if (pattern == 2 && !top_face) {
		float row = floor(local_pos.y / (pattern_scale * 0.25));
		float joints = line((along + mod(row, 2.0) * pattern_scale * 0.25) / (pattern_scale * 0.5), 1.0);
		detail = max(line(local_pos.y / (pattern_scale * 0.25), 1.0), joints);
		tint = vec3(0.85 + hash(vec2(row, floor(along / (pattern_scale * 0.5)))) * 0.3);
	} else if (pattern == 3) {
		float axis = top_face ? local_pos.z : (side_face ? local_pos.z : local_pos.y);
		float links = fract(axis / pattern_scale);
		detail = smoothstep(0.0, 0.15, links) * smoothstep(0.5, 0.35, links) * 0.8;
		if (side_face) {
			// Ruedas de rodadura
			float wheel = length(vec2(fract(local_pos.z / (pattern_scale * 2.2)) - 0.5, (local_pos.y / half_size.y) * 0.5));
			detail = max(detail * 0.5, smoothstep(0.32, 0.28, wheel) * 0.6 + smoothstep(0.1, 0.05, wheel) * 0.3);
		}
	} else if (pattern == 4) {
		detail = max(line(along / pattern_scale, 1.0), line(uv.y / pattern_scale, 1.0)) * 0.35;
		vec2 c = fract(uv / pattern_scale) - 0.08;
		float rivet = step(length(c), 0.035);
		detail = max(detail, rivet * 0.5);
	} else if (pattern == 5) {
		detail = line(uv.y / (pattern_scale * 0.25), 1.0) * 0.8;
		tint = vec3(0.85 + noise(vec2(uv.x * 8.0, floor(uv.y / (pattern_scale * 0.25)) * 3.0)) * 0.3);
	} else if (pattern == 6) {
		detail = (0.5 + 0.5 * sin(along / pattern_scale * 6.2831 * 4.0)) * 0.5;
	}

	vec3 painted = apply_camo(base_color, camo_mode, camo_a, camo_b, camo_scale, local_pos);
	vec3 color = painted * tint * (0.78 + grime * 0.38);
	color *= 1.0 - detail * 0.5;
	color = mix(color, painted * 1.5 + vec3(0.05), edge * edge_light);
	ALBEDO = color;
	ROUGHNESS = rough;
	METALLIC = metallic_value;
	EMISSION = emission;
}
