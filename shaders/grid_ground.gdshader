shader_type spatial;
render_mode cull_back;

#include "res://shaders/surface_common.gdshaderinc"

// Terreno iluminado: hierba seca, tierra, grava y rodadas, con una retícula muy tenue
// como guiño retro.
uniform vec3 grass : source_color = vec3(0.22, 0.27, 0.12);
uniform vec3 dry_grass : source_color = vec3(0.36, 0.33, 0.18);
uniform vec3 dirt : source_color = vec3(0.30, 0.23, 0.15);
uniform vec3 gravel : source_color = vec3(0.38, 0.37, 0.34);
uniform vec3 line_color : source_color = vec3(0.2, 1.0, 0.33);
uniform float grid_strength = 0.06;
uniform float cell_size = 20.0;
uniform float tint = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float large = fbm(p * 0.012);
	float medium = fbm(p * 0.06 + 13.0);
	float fine = noise(p * 1.8);
	float speck = noise(p * 7.0);
	vec3 color = mix(grass, dry_grass, smoothstep(0.35, 0.7, medium));
	color = mix(color, dirt, smoothstep(0.55, 0.75, large));
	color = mix(color, gravel, smoothstep(0.78, 0.9, fbm(p * 0.03 + 40.0)) * 0.8);
	color *= 0.8 + fine * 0.25 + speck * 0.1;
	// Rodadas de tanques: pares de franjas sinuosas
	float track_path = abs(fract((p.x + sin(p.y * 0.02) * 30.0) / 70.0) - 0.5) * 70.0;
	float ruts = smoothstep(1.2, 0.6, abs(track_path - 1.6)) * step(0.5, noise(p * 0.01 + 5.0));
	color *= 1.0 - ruts * 0.25;
	// Nieve
	color = mix(color, vec3(0.85, 0.88, 0.9) * (0.9 + fine * 0.1), tint * smoothstep(0.25, 0.6, medium + 0.2));
	vec2 coord = p / cell_size;
	vec2 dist = abs(fract(coord - 0.5) - 0.5) / (fwidth(coord) + 0.00001);
	float grid = 1.0 - clamp(min(dist.x, dist.y) / 1.5, 0.0, 1.0);
	ALBEDO = color;
	EMISSION = line_color * grid * grid_strength;
	ROUGHNESS = 0.95;
}
