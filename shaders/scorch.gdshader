shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never;

#include "res://shaders/surface_common.gdshaderinc"

// Marca de quemado en el suelo: mancha irregular con salpicaduras radiales.
instance uniform float seed = 0.0;

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float a = atan(c.y, c.x);
	float n = noise4(c * 3.0 + seed * 13.0).r * 0.6 + noise4(c * 8.0 + seed * 5.0).g * 0.4;
	float burn = 1.0 - smoothstep(0.2, 0.8, r + (n - 0.5) * 0.5);
	float rays = smoothstep(0.5, 0.8, noise4(vec2(a * 5.0 + seed * 3.0, 0.5)).b) * (1.0 - smoothstep(0.35, 0.95, r));
	ALBEDO = mix(vec3(0.07, 0.06, 0.05), vec3(0.012), burn);
	ALPHA = clamp(burn * 0.88 + rays * 0.4, 0.0, 0.9) * (1.0 - smoothstep(0.9, 1.0, r));
}
