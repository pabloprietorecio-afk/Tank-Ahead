// Parcelas del paisaje: campos vistos de lejos, propios de cada frente. Necesita
// surface_common (ruido y hash).
// biome: 0 bocage normando (prados pequeños cercados de setos, con bosquetes), 1 desierto
// (arena con manchas de piedra), 2 estepa (grandes hojas de cultivo sin lindes: trigo,
// girasol, barbecho de tierra negra).

uniform int biome = 0;
uniform vec3 field_a : source_color = vec3(0.2, 0.34, 0.12);
uniform vec3 field_b : source_color = vec3(0.34, 0.42, 0.16);
uniform vec3 field_c : source_color = vec3(0.5, 0.45, 0.2);
uniform vec3 field_line : source_color = vec3(0.08, 0.16, 0.06);

vec3 far_fields(vec2 p) {
	float large = noise4(p * 0.0021 + 7.0).r;
	float mid = noise4(p * 0.013 + 3.0).g;
	if (biome == 1) {
		// Arena con lenguas de piedra oscura (hamada) y alguna mancha clara de sal.
		vec3 sand = mix(field_a, field_b, large);
		float stone = smoothstep(0.58, 0.72, noise4(p * 0.004 + 21.0).b * 0.7 + mid * 0.3);
		sand = mix(sand, field_c, stone * 0.75);
		float salt = smoothstep(0.8, 0.9, noise4(p * 0.0015 + 40.0).a);
		return mix(sand, field_line, salt * 0.5) * (0.92 + mid * 0.16);
	}
	// Parcelas: una rejilla deformada; cada celda, un cultivo.
	vec2 size = biome == 2 ? vec2(260.0, 95.0) : vec2(78.0, 64.0);
	vec2 warp = (noise4(p * 0.004 + 11.0).rg - 0.5) * (biome == 2 ? 60.0 : 46.0);
	vec2 q = (p + warp) / size;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float pick = hash(cell);
	float shade = hash(cell + 17.0);
	vec3 crop = pick < 0.42 ? field_a : (pick < 0.74 ? field_b : field_c);
	crop *= 0.82 + shade * 0.3;
	float border = min(min(f.x, 1.0 - f.x) * size.x, min(f.y, 1.0 - f.y) * size.y);
	if (biome == 2) {
		// Surcos a lo largo de la hoja y caminos de tierra entre hojas.
		crop *= 0.94 + 0.06 * step(0.5, fract(f.y * 14.0));
		float track = 1.0 - smoothstep(1.5, 4.0, border);
		crop = mix(crop, field_line, track * 0.8);
		// Algún bosquete y las vaguadas más verdes.
		float gully = smoothstep(0.62, 0.72, noise4(p * 0.0028 + 60.0).g);
		return mix(crop, field_a * 0.6, gully * 0.7);
	}
	// Setos en las lindes y bosquetes.
	float hedge = 1.0 - smoothstep(2.5, 5.5, border + (mid - 0.5) * 3.0);
	crop = mix(crop, field_line, hedge);
	float wood = smoothstep(0.66, 0.74, noise4(p * 0.0035 + 30.0).b);
	return mix(crop, field_line * (0.9 + mid * 0.4), wood);
}
