shader_type canvas_item;

// Fondo de la portada, igual que el del final del vídeo de introducción: el negro verdoso de la
// pantalla de carga, un humo tenue que deriva y los bordes oscurecidos, todo ello «revelado» como
// película antigua (casi sin color, tirando a sepia, negros lavados) y con su grano. Repite las
// cuentas de tools/film/make_intro.py (grade y el grano): si cambian allí, aquí.

uniform vec3 base : source_color = vec3(0.051, 0.059, 0.051);
uniform vec3 smoke_color : source_color = vec3(0.21, 0.19, 0.16);
uniform float grain = 0.021;

varying vec2 local;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 p = UV * vec2(3.4, 1.9) + vec2(TIME * 0.035, TIME * 0.012);
	float smoke = 0.55 * noise(p) + 0.3 * noise(p * 2.1 + 7.0) + 0.15 * noise(p * 4.3 + 19.0);
	vec2 d = (UV - 0.5) / 0.62;
	float vignette = 1.0 - 0.55 * clamp(dot(d, d), 0.0, 1.0);
	vec3 c = (base + smoke * smoke_color * 0.42) * vignette;
	// El revelado.
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(lum), c, 0.2) * vec3(1.06, 1.0, 0.84);
	c = 9.0 / 255.0 + c * (1.0 - 16.0 / 255.0);
	vec2 e = (UV - 0.5) / 0.6;
	c *= 1.0 - 0.22 * clamp(dot(e, e), 0.0, 1.0);
	// Lo que le hace además la compresión del vídeo: algo más amarillo y con el negro sin apurar.
	c = max(c * vec3(0.95, 0.91, 0.89), vec3(0.066));
	// El grano: gordo (tres píxeles) y distinto en cada fotograma de los 24 por segundo.
	float frame = floor(TIME * 24.0);
	vec2 seed = vec2(fract(frame * 0.1031) * 91.7, fract(frame * 0.0713) * 57.3);
	float n = hash(floor(local / 3.0) + seed) + hash(floor(local / 3.0) * 1.7 + seed.yx) - 1.0;
	COLOR = vec4(c + n * grain * 2.4, 1.0);
}
