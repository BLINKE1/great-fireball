class_name HitZones

# ── Hitbox por zona: cabeça = crítico, torso = dano normal ────────────────────
# Cada inimigo tem dois Area2D filhos — "HeadHitbox" e "BodyHitbox" — na layer de
# física dedicada (HITBOX_LAYER). O dano NÃO muda de caminho: continua entrando
# por take_damage(amount, from), onde `from` é o ponto de impacto que todo
# projétil/golpe já passa. Aqui só resolvemos a zona pelo ponto e dizemos se foi
# crítico — assim nenhuma das fontes de dano (missile, espada, spells, unhas…)
# precisa saber de hitbox.
#
# Por que ponto de impacto e não colisão Area↔Area: os projéteis detectam o
# CharacterBody2D via body_entered e já mandam o ponto exato; a mira nova do
# magic missile é um projétil pontual, então o ponto é preciso. Mantém uma única
# entrada de dano e não duplica máscaras de colisão em 15 lugares.

const HITBOX_LAYER := 8       # bit de física exclusivo das hitboxes de zona
const CRIT_MULT := 2.0        # crítico = dobro do dano normal
const CRIT_COLOR := Color(1.0, 0.30, 0.12)   # vermelho-laranja do número crítico

# True se `from` (ponto de impacto, coords globais) cai na HeadHitbox do próprio
# `enemy`. Sem ponto / fora da árvore / sem cabeça → false (conta como torso).
static func is_head_hit(enemy: Node2D, from: Vector2) -> bool:
	if from == Vector2.ZERO or not enemy.is_inside_tree():
		return false
	var world := enemy.get_world_2d()
	if world == null:
		return false
	var params := PhysicsPointQueryParameters2D.new()
	params.position = from
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = 1 << (HITBOX_LAYER - 1)
	for hit in world.direct_space_state.intersect_point(params, 16):
		var col = hit.get("collider")
		if col is Area2D and col.name == "HeadHitbox" and col.get_parent() == enemy:
			return true
	return false
