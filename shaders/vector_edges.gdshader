shader_type spatial;
render_mode unshaded, cull_back;

// Caja negra con aristas luminosas. half_size = mitad de las dimensiones de la caja.
uniform vec3 half_size = vec3(1.0);
uniform vec3 line_color : source_color = vec3(0.2, 1.0, 0.33);
uniform float line_px = 1.5;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 d = half_size - abs(local_pos);
	float smallest = min(d.x, min(d.y, d.z));
	float largest = max(d.x, max(d.y, d.z));
	float second = d.x + d.y + d.z - smallest - largest;
	float line = 1.0 - clamp(second / (fwidth(second) * line_px + 0.00001), 0.0, 1.0);
	ALBEDO = line_color * line;
}
