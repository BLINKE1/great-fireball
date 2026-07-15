shader_type canvas_item;
// Feather das bordas por POSICAO local (nao UV) — imune ao region_rect/repeat
// dos tiles de terreno. Dissolve o retangulo do sprite na cena:
//  - plataforma: feather so' nas laterais (topo continua nitido = ledge)
//  - backwall:   feather nos 4 lados (vira cavidade de rocha, nao painel)
uniform vec2 half_size = vec2(100.0, 40.0);
uniform vec2 feather = vec2(28.0, 0.0);   // px de feather em x e y; 0 = sem
varying vec2 vpos;

void vertex() {
	vpos = VERTEX;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 d = half_size - abs(vpos);            // distancia pra borda mais proxima
	float fx = feather.x > 0.5 ? clamp(d.x / feather.x, 0.0, 1.0) : 1.0;
	float fy = feather.y > 0.5 ? clamp(d.y / feather.y, 0.0, 1.0) : 1.0;
	c.a *= fx * fy;
	COLOR = c;
}
