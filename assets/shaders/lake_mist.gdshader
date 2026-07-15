shader_type canvas_item;
// Nevoa baixa driftando rente a' linha d'agua (atmosfera Ori). Faixa horizontal
// suave (gaussiana) centrada na margem, modulada por fbm que desliza no tempo.
// Roda numa CanvasLayer na frente da agua e atras da folhagem. band_center vem
// do level_visuals por frame (mesma projecao da linha d'agua).
uniform float band_center = 0.6;              // y da faixa em tela (0..1)
uniform float band_half = 0.20;               // meia-altura da faixa
uniform vec3 fog_color : source_color = vec3(0.60, 0.79, 0.75);
uniform float density = 0.52;
uniform float drift = 0.020;

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
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void fragment() {
	float t = TIME;
	float vy = (SCREEN_UV.y - band_center) / band_half;   // -1..1 na faixa
	float band = exp(-vy * vy * 2.2);                     // gaussiana vertical
	vec2 uv = vec2(SCREEN_UV.x * 3.2 + t * drift, SCREEN_UV.y * 4.0 - t * drift * 0.4);
	float f = fbm(uv);
	f = smoothstep(0.32, 0.92, f);
	COLOR = vec4(fog_color, band * f * density);
}
