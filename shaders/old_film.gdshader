shader_type canvas_item;

// Desperfectos de película antigua por encima de la pantalla de idioma, como los del vídeo de
// introducción (tools/film/make_intro.py): parpadeo, rayas verticales que duran unos fotogramas y
// alguna mota. El grano y el tono van en el fondo y en el título, no aquí.

uniform float strength = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float frame = floor(TIME * 24.0);
	float tick = fract(frame * 0.0619) * 73.0;
	// Parpadeo: algunos fotogramas salen algo más oscuros.
	float dim = max(hash(vec2(tick, 3.7)) - 0.5, 0.0) * 0.07;
	dim += step(0.96, hash(vec2(tick, 9.1))) * 0.07;
	vec3 color = vec3(0.0);
	float alpha = dim;
	// Rayas: dos carriles; cada una dura medio segundo escaso, tiembla y va a trozos.
	for (int lane = 0; lane < 2; lane++) {
		float spell = floor((frame + float(lane) * 5.0) / 11.0);
		vec2 key = vec2(fract(spell * 0.137) * 61.0, float(lane) * 7.3 + 1.0);
		if (hash(key) < 0.55) {
			float x = 0.04 + 0.92 * hash(key + 2.9) + (hash(vec2(tick, key.y)) - 0.5) * 0.0016;
			float line = 1.0 - smoothstep(0.0006, 0.0014, abs(UV.x - x));
			float run = step(0.25, hash(vec2(floor(UV.y * 30.0), tick + key.y)));
			float mark = line * run * (0.14 + 0.16 * hash(key + 5.3));
			float light = step(0.25, hash(key + 8.1));
			color = mix(color, vec3(light), mark / max(alpha + mark, 0.001));
			alpha = alpha + mark * (1.0 - alpha);
		}
	}
	// Motas: una, casi todos los fotogramas.
	vec2 at = vec2(hash(vec2(tick, 21.0)), hash(vec2(tick, 34.0)));
	vec2 gap = (UV - at) * vec2(16.0 / 9.0, 1.0);
	float size = 0.0015 + 0.004 * hash(vec2(tick, 47.0));
	float dot_mark = (1.0 - smoothstep(size * 0.6, size, length(gap))) * 0.8;
	float pale = step(0.7, hash(vec2(tick, 55.0)));
	color = mix(color, vec3(0.08 + 0.84 * pale), dot_mark / max(alpha + dot_mark, 0.001));
	alpha = alpha + dot_mark * (1.0 - alpha);
	COLOR = vec4(color, alpha * strength);
}
