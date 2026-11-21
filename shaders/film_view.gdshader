shader_type canvas_item;

// La vista del juego como película de guerra antigua, para el vuelo de entrada a las misiones:
// casi en blanco y negro tirando a sepia, negros lavados, bordes oscuros, grano gordo, parpadeo,
// baile de la ventanilla, rayas y motas. Las mismas cuentas que el vídeo de introducción
// (tools/film/make_intro.py). `strength` lo gradúa: a 0 deja la imagen tal cual.

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform float strength = 1.0;
uniform float contrast = 1.45;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float frame = floor(TIME * 24.0);
	float tick = fract(frame * 0.0619) * 73.0;
	// Baile de la ventanilla: la imagen sube y baja un pelo, y de tarde en tarde da un salto.
	float weave = sin(frame * 0.9) * 1.2 + (hash(vec2(tick, 61.0)) - 0.5) * 1.4;
	weave += step(0.985, hash(vec2(tick, 77.0))) * 8.0;
	vec2 uv = SCREEN_UV + vec2((hash(vec2(tick, 83.0)) - 0.5) * 0.6 / 1280.0, weave / 720.0) * strength;
	vec3 plain = texture(screen, SCREEN_UV).rgb;
	vec3 c = texture(screen, uv).rgb;
	// El revelado.
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(lum), c, 0.2);
	// Más contraste que el vídeo: el campo visto desde arriba, con su bruma, queda plano sin él.
	c = clamp((c - 0.5) * contrast + 0.5 - 0.06, 0.0, 1.0) * vec3(1.06, 1.0, 0.84);
	c = 9.0 / 255.0 + c * (1.0 - 16.0 / 255.0);
	vec2 e = (SCREEN_UV - 0.5) / 0.6;
	c *= 1.0 - 0.42 * clamp(dot(e, e), 0.0, 1.0);
	// Parpadeo.
	c *= 1.0 + (hash(vec2(tick, 3.7)) - 0.5) * 0.09 - step(0.96, hash(vec2(tick, 9.1))) * 0.09;
	// Grano: de tres píxeles (a 720 de alto) y distinto 12 veces por segundo.
	float cell = 3.0 / (SCREEN_PIXEL_SIZE.y * 720.0);
	float pace = floor(frame * 0.5);
	vec2 seed = vec2(fract(pace * 0.1031) * 91.7, fract(pace * 0.0713) * 57.3);
	vec2 at = floor(FRAGCOORD.xy / cell);
	c += (hash(at + seed) + hash(at * 1.7 + seed.yx) - 1.0) * 0.085;
	// Rayas: dos carriles; cada una dura medio segundo escaso, tiembla y va a trozos.
	for (int lane = 0; lane < 2; lane++) {
		float spell = floor((frame + float(lane) * 5.0) / 11.0);
		vec2 key = vec2(fract(spell * 0.137) * 61.0, float(lane) * 7.3 + 1.0);
		if (hash(key) < 0.55) {
			float x = 0.04 + 0.92 * hash(key + 2.9) + (hash(vec2(tick, key.y)) - 0.5) * 0.0016;
			float line = 1.0 - smoothstep(0.0006, 0.0014, abs(SCREEN_UV.x - x));
			float run = step(0.25, hash(vec2(floor(SCREEN_UV.y * 30.0), tick + key.y)));
			float light = step(0.25, hash(key + 8.1)) * 2.0 - 1.0;
			c += line * run * light * (0.14 + 0.16 * hash(key + 5.3));
		}
	}
	// Motas.
	vec2 spot = vec2(hash(vec2(tick, 21.0)), hash(vec2(tick, 34.0)));
	vec2 gap = (SCREEN_UV - spot) * vec2(16.0 / 9.0, 1.0);
	float size = 0.0015 + 0.004 * hash(vec2(tick, 47.0));
	float mark = (1.0 - smoothstep(size * 0.6, size, length(gap))) * 0.8;
	c = mix(c, vec3(0.08 + 0.84 * step(0.7, hash(vec2(tick, 55.0)))), mark);
	COLOR = vec4(mix(plain, clamp(c, 0.0, 1.0), strength), 1.0);
}
