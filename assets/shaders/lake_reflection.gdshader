shader_type canvas_item;
// LAGO — reflexo da floresta na faixa abaixo da linha d'agua.
// Roda numa CanvasLayer atras do mundo (so' o backdrop ja' desenhado no
// screen_tex): espelha o que esta' ACIMA da linha d'agua pra baixo, ondula,
// tinge de agua, escurece com a profundidade e poe espuma na margem.
// A waterline_uv (posicao da margem em tela) e' atualizada por frame pelo
// level_visuals a partir da camera -> cola no chao em qualquer zoom/pulo.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float waterline_uv = 0.6;                       // y da margem (0 topo .. 1 base)
uniform vec3 water_tint : source_color = vec3(0.16, 0.42, 0.46);
uniform float ripple_amp = 0.012;
uniform float ripple_freq = 34.0;
uniform float ripple_speed = 0.6;
uniform float tint_amount = 0.35;
uniform float depth_darken = 0.38;

void fragment() {
	if (SCREEN_UV.y <= waterline_uv) {
		COLOR = vec4(0.0);                               // acima da agua: transparente
	} else {
		float span = max(0.001, 1.0 - waterline_uv);
		float depth = (SCREEN_UV.y - waterline_uv) / span;   // 0 na margem .. 1 no fundo
		// ondulacao horizontal cresce com a profundidade
		float amp = ripple_amp * (0.25 + depth);
		float wob = sin(SCREEN_UV.y * ripple_freq + TIME * ripple_speed * 2.0) * amp
				  + sin(SCREEN_UV.y * ripple_freq * 2.7 - TIME * ripple_speed * 1.3) * amp * 0.5;
		// fonte ESPELHADA: mesma distancia acima da linha d'agua
		float src_y = waterline_uv - (SCREEN_UV.y - waterline_uv);
		vec3 refl = texture(screen_tex, vec2(SCREEN_UV.x + wob, src_y)).rgb;
		vec3 col = mix(refl, water_tint, tint_amount + depth * 0.30);
		col *= (1.0 - depth * depth_darken);
		// brilho especular deslizando na superficie
		float g = smoothstep(0.9, 1.0, sin(SCREEN_UV.x * 40.0 - TIME * 0.7) * 0.5 + 0.5);
		g *= (1.0 - smoothstep(0.0, 0.18, depth));
		col += g * 0.07;
		// linha d'agua / espuma na margem
		float foam = 1.0 - smoothstep(0.0, 0.022, depth);
		col = mix(col, vec3(0.72, 0.90, 0.83), foam * 0.55);
		COLOR = vec4(col, 1.0);
	}
}
