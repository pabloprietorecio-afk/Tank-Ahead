shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 line_color : source_color = vec3(0.2, 1.0, 0.33);
uniform float cell_size = 10.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 coord = world_pos.xz / cell_size;
	vec2 dist = abs(fract(coord - 0.5) - 0.5) / (fwidth(coord) + 0.00001);
	float line = 1.0 - clamp(min(dist.x, dist.y) / 1.5, 0.0, 1.0);
	ALBEDO = line_color * line;
}
