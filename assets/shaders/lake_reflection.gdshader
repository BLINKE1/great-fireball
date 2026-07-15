shader_type canvas_item;
// LAGO — reflexo da floresta na faixa abaixo da linha d'agua.
// Roda numa CanvasLayer DEPOIS do mundo (screen_tex ja' tem backdrop+arvores+
// Soph): espelha o que esta' ACIMA da margem pra baixo, ondula, mistura com a
// cor da agua (gradiente raso->fundo), cintila nos brilhos refletidos (god-rays)
// e poe sheen/espuma na margem. waterline_uv vem do level_visuals por frame.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float waterline_uv = 0.6;                            // y da margem (0..1)
uniform vec3 water_shallow : source_color = vec3(0.18, 0.44, 0.46);
uniform vec3 water_deep : source_color = vec3(0.05, 0.16, 0.22);
uniform float ripple_amp = 0.010;
uniform float ripple_freq = 30.0;
uniform float ripple_speed = 0.5;
uniform float reflect_strength = 0.85;
uniform float shimmer = 0.10;

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i), b = hash(i + vec2(1, 0));
	float c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	if (SCREEN_UV.y <= waterline_uv) {
		COLOR = vec4(0.0);                                   // acima da agua: transparente
	} else {
		float span = max(0.001, 1.0 - waterline_uv);
		float depth = (SCREEN_UV.y - waterline_uv) / span;   // 0 margem .. 1 fundo
		float t = TIME * ripple_speed;
		// ondulacao: 2 octaves, cresce com a profundidade
		float amp = ripple_amp * (0.2 + depth);
		float wob = sin(SCREEN_UV.y * ripple_freq + t * 2.0) * amp
				  + sin(SCREEN_UV.y * ripple_freq * 2.7 - t * 1.3) * amp * 0.5;
		// fonte ESPELHADA: mesma distancia acima da margem
		float src_y = waterline_uv - (SCREEN_UV.y - waterline_uv);
		vec3 refl = texture(screen_tex, vec2(SCREEN_UV.x + wob, src_y)).rgb;
		// cor da agua (gradiente) + reflexo enfraquecendo no fundo
		vec3 water = mix(water_shallow, water_deep, clamp(depth * 1.1, 0.0, 1.0));
		float rstr = reflect_strength * (1.0 - depth * 0.55);
		vec3 col = mix(water, refl, rstr);
		// realca o brilho refletido (god-rays) -> cintila na agua
		float lum = dot(refl, vec3(0.299, 0.587, 0.114));
		float hi = smoothstep(0.55, 0.9, lum);
		float sh = vnoise(vec2(SCREEN_UV.x * 80.0 + t * 3.0, SCREEN_UV.y * 22.0 - t * 1.5));
		sh = smoothstep(0.6, 1.0, sh);
		col += hi * sh * shimmer * vec3(0.8, 1.0, 0.9);
		// sheen: luz raspando a superficie logo abaixo da margem (sutil)
		col += (1.0 - smoothstep(0.0, 0.16, depth)) * 0.035 * vec3(0.78, 0.92, 0.9);
		// margem: leve escurecida de contato + fio de espuma palido QUEBRADO por
		// ruido no x (margem irregular, nao um risco reto e uniforme)
		col *= 1.0 - (1.0 - smoothstep(0.0, 0.010, depth)) * 0.15;
		float fbreak = 0.45 + 0.55 * vnoise(vec2(SCREEN_UV.x * 46.0 + t, 5.0));
		float foam = (1.0 - smoothstep(0.006, 0.032, depth)) * fbreak;
		col = mix(col, vec3(0.82, 0.90, 0.88), foam * 0.22);
		COLOR = vec4(col, 1.0);
	}
}
