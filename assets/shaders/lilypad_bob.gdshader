shader_type canvas_item;
// Flutuacao suave da vitoria-regia na agua (bob vertical + deriva minima).
// Cada pad recebe 'phase' proprio -> nao bobam em uniso.
uniform float phase = 0.0;
uniform float bob = 1.6;

void vertex() {
	VERTEX.y += sin(TIME * 0.8 + phase) * bob;
	VERTEX.x += sin(TIME * 0.55 + phase * 1.3) * bob * 0.55;
}
