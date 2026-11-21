shader_type canvas_item;

// Fondo de la portada, igual que el del final del vídeo de introducción: el negro verdoso de la
// pantalla de carga, un humo tenue que deriva y los bordes oscurecidos.

uniform vec3 base : source_color = vec3(0.051, 0.059, 0.051);
uniform vec3 smoke_color : source_color = vec3(0.21, 0.19, 0.16);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * vec2(3.4, 1.9) + vec2(TIME * 0.035, TIME * 0.012);
	float smoke = 0.55 * noise(p) + 0.3 * noise(p * 2.1 + 7.0) + 0.15 * noise(p * 4.3 + 19.0);
	vec2 d = (UV - 0.5) / 0.62;
	float vignette = 1.0 - 0.55 * clamp(dot(d, d), 0.0, 1.0);
	COLOR = vec4((base + smoke * smoke_color * 0.5) * vignette, 1.0);
}
