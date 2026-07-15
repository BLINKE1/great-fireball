shader_type canvas_item;
// Vento na folhagem: o TOPO balança, a BASE fica plantada. Cada instancia
// recebe uma 'phase' diferente (da posicao no mundo) -> nao balancam em uniso.
// Sprites do foreground sao centered=false: UV.y=0 topo, UV.y=1 base.
uniform float amp = 3.0;      // px de balanco no topo
uniform float speed = 1.3;
uniform float phase = 0.0;

void vertex() {
	float s = sin(TIME * speed + phase) + 0.4 * sin(TIME * speed * 0.53 + phase * 1.7);
	float k = 1.0 - UV.y;                 // 1 no topo, 0 na base
	VERTEX.x += s * amp * k * k;          // k^2: base bem firme, topo solto
}
