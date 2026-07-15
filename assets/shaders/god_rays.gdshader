shader_type canvas_item;
render_mode blend_add;
// Feixes de luz volumetricos (god rays) atravessando a copa. Aditivo e sutil,
// numa CanvasLayer atras do player (atmosfera de fundo). fbm ao longo do eixo
// perpendicular aos raios -> shafts irregulares; deriva lenta = luz respirando.
uniform vec3 ray_color : source_color = vec3(0.55, 0.72, 0.46);
uniform float intensity = 0.085;
uniform float angle = 0.34;      // inclinacao dos raios (rad)
uniform float density = 6.5;
uniform float top_bias = 1.0;    // 1 = mais forte em cima

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i), b = hash(i + vec2(1, 0));
	float c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 3; i++) { v += a * vnoise(p); p *= 2.05; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float axis = uv.x * cos(angle) - uv.y * sin(angle);   // eixo perpendicular
	float n = fbm(vec2(axis * density, TIME * 0.04));
	float beams = smoothstep(0.52, 1.0, n);
	float vfade = mix(1.0, smoothstep(1.05, 0.05, uv.y), top_bias);  // some pra baixo
	COLOR = vec4(ray_color, beams * vfade * intensity);
}
