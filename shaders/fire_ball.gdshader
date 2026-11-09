shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, shadows_disabled, specular_disabled, diffuse_lambert_wrap;

#include "res://shaders/surface_common.gdshaderinc"

// Bocanada de fuego o humo: una esfera abultada con ruido cuyos bordes se difuminan y que
// se va deshaciendo en jirones. `heat` 1 = fuego que se enfría hasta volverse humo,
// 0 = humo o polvo del color `tint`. Cada bocanada lleva su propia `life` (0..1).
instance uniform float life = 0.0;
instance uniform float seed = 0.0;
instance uniform float heat = 1.0;
instance uniform vec3 tint : source_color = vec3(0.07, 0.065, 0.06);

varying vec3 lp;

void vertex() {
	vec3 dir = normalize(VERTEX + vec3(0.0001));
	vec2 key = dir.xz * 1.9 + dir.y * 1.4 + seed * 17.0 + life * 0.8;
	float bulge = textureLod(noise_tex, (key + 0.5) / 64.0 * 2.5, 0.0).r;
	VERTEX *= 1.0 + (bulge - 0.5) * 0.3;
	lp = VERTEX;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	vec2 uv = lp.xy * 1.5 + lp.z * 1.1 + seed * 9.0;
	uv.y -= life * 0.9;
	float n = noise4(uv * 2.2).r * 0.6 + noise4(uv * 5.3 + 3.0).g * 0.4;
	// Temperatura: cae con la vida; el ruido deja vetas más calientes.
	float temp = clamp(heat * (1.0 - life * 1.5) * (0.55 + n * 0.9), 0.0, 1.6);
	vec3 fire = mix(vec3(0.75, 0.08, 0.01), vec3(1.0, 0.45, 0.06), smoothstep(0.1, 0.45, temp));
	fire = mix(fire, vec3(1.0, 0.85, 0.45), smoothstep(0.5, 0.9, temp));
	fire = mix(fire, vec3(1.0, 0.98, 0.9), smoothstep(1.0, 1.4, temp));
	float glow = smoothstep(0.05, 0.3, temp);
	vec3 smoke = mix(tint, vec3(0.03, 0.028, 0.026), heat * 0.6) * (0.55 + n * 0.9);
	ALBEDO = smoke * (1.0 - glow);
	EMISSION = fire * glow * (1.2 + temp);
	ROUGHNESS = 1.0;
	float erode = smoothstep(life - 0.3, life + 0.12, n * 0.85 + 0.12);
	float fade = 1.0 - smoothstep(0.7, 1.0, life);
	float density = mix(0.8, 1.0, glow);
	ALPHA = smoothstep(0.05, 0.75, facing) * erode * fade * density;
}
