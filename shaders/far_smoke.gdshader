shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Columna de humo lejana: un panel alto, de cara al campo, con el humo subiendo y
// torciéndose con el viento. UV.y = 1 en la base.
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec3 smoke_color : source_color = vec3(0.1, 0.1, 0.11);
uniform vec3 top_color : source_color = vec3(0.36, 0.36, 0.38);
uniform float lean = 0.35;
uniform float seed = 0.0;
uniform float opacity = 0.8;

void fragment() {
	float up = 1.0 - UV.y;
	// El eje de la columna se va con el viento según sube, y se abre.
	float axis = 0.5 - lean * 0.5 + lean * up * up + (texture(noise_tex, vec2(seed, up * 0.4 - TIME * 0.01)).r - 0.5) * 0.18 * up;
	float width = mix(0.035, 0.26, pow(up, 0.75));
	float across = abs(UV.x - axis) / width;
	float puffs = texture(noise_tex, vec2(UV.x * 1.6 + seed, UV.y * 2.2 + TIME * 0.022)).g * 0.6 + texture(noise_tex, vec2(UV.x * 4.5 - seed, UV.y * 6.0 + TIME * 0.05)).b * 0.4;
	float body = 1.0 - smoothstep(0.35, 1.0, across + (puffs - 0.5) * 0.9);
	float fade = smoothstep(0.0, 0.04, up) * (1.0 - smoothstep(0.55, 1.0, up));
	ALBEDO = mix(smoke_color, top_color, up * 0.9 + (puffs - 0.5) * 0.3);
	ALPHA = body * fade * opacity;
}
