shader_type spatial;
render_mode unshaded, cull_back;

// Relleno con textura procedural para mallas no cúbicas.
// pattern: 0 liso, 1 corteza, 2 follaje, 3 roca estratificada, 4 metal con aros, 5 tejas, 6 madera.
uniform vec3 fill_color : source_color = vec3(0.0, 0.03, 0.01);
uniform vec3 detail_color : source_color = vec3(0.2, 1.0, 0.33);
uniform int pattern = 0;
uniform float scale = 1.0;
uniform float strength = 0.45;

varying vec3 lp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float line(float coord) {
	float f = abs(fract(coord - 0.5) - 0.5);
	return 1.0 - clamp(f / (fwidth(coord) * 1.2 + 0.00001), 0.0, 1.0);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 p = lp / scale;
	float around = atan(p.z, p.x);
	float d = 0.0;
	if (pattern == 1) {
		d = line(around * 2.0 + noise(vec2(p.y * 3.0, 0.0)) * 0.6);
	} else if (pattern == 2) {
		float n = noise(vec2(around * 3.0, p.y * 6.0) + p.xz * 2.0);
		d = max(step(0.72, n), line(p.y * 4.0) * 0.6);
	} else if (pattern == 3) {
		float strata = line(p.y * 1.5 + noise(p.xz * 0.8) * 1.2);
		float cracks = line(around * 3.0 + noise(vec2(p.y, around)) * 1.5) * step(0.55, noise(p.xz * 1.5 + p.y));
		d = max(strata, cracks * 0.8);
	} else if (pattern == 4) {
		d = max(line(p.y * 2.5), step(0.93, sin(around * 6.0)) * line(p.y * 5.0));
	} else if (pattern == 5) {
		float row = floor(p.y * 4.0);
		d = max(line(p.y * 4.0), line(p.x * 2.5 + mod(row, 2.0) * 0.5) * 0.7);
	} else if (pattern == 6) {
		d = line(p.x * 1.5 + noise(p.yz * 4.0) * 0.4) * 0.7;
	}
	ALBEDO = fill_color + detail_color * d * strength;
}
