shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 line_color : source_color = vec3(0.2, 1.0, 0.33);
uniform vec3 soil_dark : source_color = vec3(0.0, 0.025, 0.008);
uniform vec3 soil_light : source_color = vec3(0.02, 0.07, 0.025);
uniform float cell_size = 10.0;
uniform float tint = 0.0;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 coord = world_pos.xz / cell_size;
	vec2 dist = abs(fract(coord - 0.5) - 0.5) / (fwidth(coord) + 0.00001);
	float line = 1.0 - clamp(min(dist.x, dist.y) / 1.5, 0.0, 1.0);
	// Textura procedural del terreno: manchas grandes + grano fino.
	float patches = noise(world_pos.xz * 0.02) * 0.65 + noise(world_pos.xz * 0.09) * 0.35;
	float grain = noise(world_pos.xz * 1.3);
	vec3 soil = mix(soil_dark, soil_light, smoothstep(0.35, 0.75, patches));
	soil *= 0.75 + grain * 0.5;
	soil = mix(soil, vec3(0.55, 0.6, 0.58), tint * smoothstep(0.3, 0.7, patches));
	ALBEDO = soil + line_color * line * 0.85;
}
