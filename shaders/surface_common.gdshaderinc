// Funciones comunes de las texturas procedurales.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.5 + noise(p * 2.03) * 0.3 + noise(p * 4.1) * 0.2;
}

float line(float coord, float width) {
	float f = abs(fract(coord - 0.5) - 0.5);
	return 1.0 - clamp(f / (fwidth(coord) * width + 0.00001), 0.0, 1.0);
}

vec3 apply_camo(vec3 base, int mode, vec3 a, vec3 b, float scale, vec3 pos) {
	if (mode == 0) {
		return base;
	}
	vec2 p = (pos.xz + vec2(pos.y * 0.7, -pos.y * 0.5)) / scale;
	if (mode == 1) {
		float n1 = fbm(p * 0.9);
		float n2 = fbm(p * 0.9 + 17.3);
		vec3 c = mix(base, a, smoothstep(0.52, 0.56, n1));
		return mix(c, b, smoothstep(0.6, 0.64, n2));
	} else if (mode == 2) {
		float band = sin((p.x + p.y * 0.6) * 2.2 + fbm(p) * 3.0);
		vec3 c = mix(base, a, smoothstep(0.35, 0.45, band));
		return mix(c, b, smoothstep(0.35, 0.45, -band) * step(0.5, fbm(p * 1.3)));
	}
	// Encalado de invierno: blanco con desconchones del color base.
	float worn = fbm(p * 2.0);
	return mix(vec3(0.82, 0.84, 0.86), base, smoothstep(0.62, 0.7, worn));
}
