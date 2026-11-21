shader_type canvas_item;

// Título «A / TANK / STORY» de la portada. Con `tint` a 0 es tinta crema, como en el vídeo de
// introducción; con `tint` a 1 las letras se visten con la bandera del idioma elegido: la
// bandera se extiende por todo el bloque del título y cada letra enseña el trozo que le toca.
// Al cambiar de idioma se pasa de una bandera a otra con `blend`.
// Los vértices pintados en negro son el perfil claro que deja leer los colores oscuros.

uniform sampler2D flag_from : filter_linear, repeat_disable;
uniform sampler2D flag_to : filter_linear, repeat_disable;
uniform float blend = 1.0;
uniform float tint = 0.0;
uniform vec3 ink : source_color = vec3(0.91, 0.88, 0.78);
// Rectángulo del bloque del título en coordenadas del control: x, y, ancho, alto.
uniform vec4 block = vec4(0.0, 0.0, 1.0, 1.0);

varying vec2 local;
varying float fill;

void vertex() {
	local = VERTEX;
	fill = COLOR.r;
}

void fragment() {
	vec2 uv = clamp((local - block.xy) / block.zw, 0.0, 1.0);
	vec3 flag = mix(texture(flag_from, uv).rgb, texture(flag_to, uv).rgb, blend);
	// Algo desteñida, como la tinta del resto.
	flag = mix(flag, ink, 0.1);
	vec3 body = mix(ink, flag, tint);
	float is_fill = step(0.5, fill);
	COLOR = vec4(mix(ink, body, is_fill), COLOR.a * mix(0.6 * tint, 1.0, is_fill));
}
